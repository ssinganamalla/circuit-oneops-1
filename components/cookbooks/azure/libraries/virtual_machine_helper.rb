module AzureCompute
  class VirtualMachineHelper

    attr_accessor :client, :subscription_id

    def initialize(node)
      @cloud_name = node['workorder']['cloud']['ciName']
      @compute_service =
          node['workorder']['services']['compute'][cloud_name]['ciAttributes']
      @keypair_service = node['workorder']['payLoad']['SecuredBy'].first
      @server_name = node['server_name']
      @resource_group_name = node['platform-resource-group']
      @imageID = node['image_id'].split(':')
      @ci_id = node['workorder']['rfcCi']['ciId']

      @client = Fog::Compute::AzureRM.new({ tenant_id: @compute_service[:tenant_id],
                                            client_id: @compute_service[:client_id],
                                            client_secret: @compute_service[:client_secret],
                                            subscription_id: @compute_service[:subscription] })
    end

    def check_vm_exists?
      begin
        exists = @client.check_vm_exists?(@resource_group_name, @server_name)
        OOLog.debug("VM Exists?: #{exists}")
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end

    def create_or_update()

      # create storage account if needed
      begin
        storage_account_name = get_storage_account_name()
        create_storage_account(storage_account_name)
      rescue => e
        OOLog.fatal("Error creating storage account: #{storage_account_name}: #{e.message}")
      end

      # build hash containing vm info
      # used in Fog::Compute::AzureRM::create_virtual_machine()
      vm_hash = {}

      # common values
      vm_hash[:name] = node['server_name']
      vm_hash[:resource_group] = node['platform-resource-group']
      vm_hash[:availability_set_id] =
          client.get_availability_set(node['platform-resource-group'], node['platform-availability-set']).id
      vm_hash[:location] = compute_service[:location]

      # hardware profile values
      vm_hash[:vm_size] = node['size_id']

      # storage profile values
      vm_hash[:storage_account_name] = storage_account_name
      vm_hash[:publisher] = imageID[0]
      vm_hash[:offer] = imageID[1]
      vm_hash[:sku] = imageID[2]
      vm_hash[:version] = imageID[3]

      # os profile values
      vm_hash[:username] = compute_service[:initial_user]
      vm_hash[:disable_password_authentication] = true
      vm_hash[:ssh_key_path] = "/home/#{initial_user}/.ssh/authorized_keys"
      vm_hash[:ssh_key_data] = keypair[:ciAttributes][:public]

      # network profile values
      vm_hash[:network_interface_card_id] =

      # create the virtual machine
      begin
        @client.create_virtual_machine(vm_hash)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end

    private

    def create_storage_account(storage_account_name)
      if storage_name_avail?(storage_account_name)
        replication = "LRS"
        if node[:size_id] =~ /(.*)GS(.*)|(.*)DS(.*)/
          sku_name = "Premium"
        else
          sku_name = "Standard"
        end

        OOLog.info("VM size: #{node[:size_id]}")
        OOLog.info("Storage Type: #{sku_name}_#{replication}")

        storage_account =
            @client.create_storage_account({ name: storage_account_name,
                                             resource_groupe: @resource_group_name,
                                             location: @compute_service[:location],
                                             sku_name: sku_name,
                                             replication: replication })
        if storage_account.nil?
          OOLog.fatal("***FAULT:FATAL=Could not create storage account #{storage_account_name}")
        end
      end

      i = 0
      until storage_account_created?(storage_account_name) do
        if(i >= 10)
          OOLog.fatal("***FAULT:FATAL=Timeout. Could not find storage account #{storage_account_name}")
        end
        i += 1
        sleep 30
      end
    end

    def get_storage_account_name()
      generated_name = "oostg" + @ci_id.to_s + Utils.abbreviate_location(@location)

      # making sure we are not over the limit
      if generated_name.length > 22
        generated_name = generated_name.slice!(0..21)
      end

      OOLog.info("Generated Storage Account Name: #{generated_name}")
      OOLog.info("Getting Resource Group '#{@resource_group_name}' VM count")
      vm_count = get_resource_group_vm_count
      OOLog.info("Resource Group VM Count: #{vm_count}")

      storage_accounts = generate_storage_account_names(generated_name)

      storage_index = calculate_storage_index(storage_accounts, vm_count)
      if storage_index < 0
        OOLog.fatal("No storage account can be selected!")
      end

      storage_accounts[storage_index]
    end

    # This function will generate all possible storage account NAMES
    # for current Resource Group.
    def generate_storage_account_names(storage_account_name)
      # The max number of resources in a Resource Group is 800
      # Microsoft guidelines is 40 Disks per storage account
      # to not affect performance
      # So the most storage accounts we could have per Resource Group is 800/40
      limit = 800/40

      storage_accounts = Array.new

      (1..limit).each do |index|
        if index < 10
          account_name =  "#{storage_account_name}0" + index.to_s
        else
          account_name =  "#{storage_account_name}" + index.to_s
        end
        storage_accounts[index-1] = account_name
      end

      storage_accounts
    end

    #Calculate the index of the storage account name array
    #based on the number of virtual machines created on the
    #current subscription
    def calculate_storage_index(storage_accounts, vm_count)
      increment = 40
      storage_account = 0
      vm_count += 1
      storage_count = storage_accounts.size - 1

      (0..storage_count).each do |storage_index|
        storage_account += increment
        if vm_count <= storage_account
          return storage_index
        end
      end
      -1
    end

    def get_resource_group_vm_count
      vm_count = 0
      vm_list = @compute_client.virtual_machines.list(@resource_group_name)
      if !vm_list.nil? and !vm_list.empty?
        vm_count = vm_list.size
      else
        vm_count = 0
      end
      vm_count
    end

    def storage_name_avail?(storage_account_name)
      begin
        params = Azure::ARM::Storage::Models::StorageAccountCheckNameAvailabilityParameters.new
        params.name = storage_account_name
        params.type = 'Microsoft.Storage/storageAccounts'
        response =
            @client.check_storage_account_name_availability(params)
        OOLog.info("Storage Name Available: #{response}")
      rescue  MsRestAzure::AzureOperationError => e
        OOLog.info("ERROR checking availability of #{storage_account_name}")
        OOLog.info("ERROR Body: #{e.body}")
        return nil
      rescue => ex
        OOLog.fatal("Error checking availability of #{storage_account_name}: #{ex.message}")
      end
    end

    def storage_account_created?(storage_account_name)
      begin
        response =
            @client.get_storage_account(@resource_group_name, storage_account_name)
        OOLog.info("Storage Account Provisioning State: #{response.provisioning_state}")
      rescue  MsRestAzure::AzureOperationError => e
        OOLog.info("#ERROR Body: #{e.body}")
        return false
      rescue => ex
        OOLog.fatal("Error getting properties of #{storage_account_name}: #{ex.message}")
      end

      response.provisioning_state == 'Succeeded'
    end
  end
end