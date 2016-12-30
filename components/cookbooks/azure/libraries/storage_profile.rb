module AzureCompute
  class StorageProfile

    attr_accessor :location,
                  :resource_group_name

    attr_reader :creds, :subscription

    def initialize(creds, subscription)
      @creds = creds
      @subscription = subscription
      @storage_client =
        Azure::ARM::Storage::StorageManagementClient.new(creds)
      @storage_client.subscription_id = subscription

      @compute_client =
        Azure::ARM::Compute::ComputeManagementClient.new(creds)
      @compute_client.subscription_id = subscription

    end

    def build_profile(node)
      #==================================================
      #Get the information from the workload in order to
      #extract the platform name and generate
      #the storage account name
      workorder = node["workorder"]["rfcCi"]
      nsPathParts = workorder["nsPath"].split("/")
      org = nsPathParts[1]
      assembly = nsPathParts[2]
      platform = nsPathParts[5]

      # Azure storage accout name restrinctions:
      # alpha-numberic  no special characters between 9 and 24 characters
      # name needs to be globally unique, but it also needs to be per region.
      generated_name = "oostg" + node.workorder.box.ciId.to_s + Utils.abbreviate_location(@location)

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

      storage_account_name = storage_accounts[storage_index]

      #Check for Storage account availability
      # (if storage account is created or not)
      #Available means the storage account has not been created
      # (need to create it)
      #Otherwise, it is created and we can use it
      if storage_name_avail?(storage_account_name)
        #Storage account name is available; Need to create storage account
        #Select the storage according to VM size
        account_type = Azure::ARM::Storage::Models::Sku.new
        if node[:size_id] =~ /(.*)GS(.*)|(.*)DS(.*)/
          account_type.name = Azure::ARM::Storage::Models::SkuName::PremiumLRS
          account_type.tier = Azure::ARM::Storage::Models::SkuTier::Premium
        else
          account_type.name = Azure::ARM::Storage::Models::SkuName::StandardLRS
          account_type.tier = Azure::ARM::Storage::Models::SkuTier::Standard
        end

        OOLog.info("VM size: #{node[:size_id]}")
        OOLog.info("Storage Type: #{account_type.name}")

        storage_account =
          create_storage_account(storage_account_name, account_type)
        if storage_account.nil?
          OOLog.fatal("***FAULT:FATAL=Could not create storage account #{storage_account_name}")
        end
      else
        OOLog.info("No need to create Storage Account: #{storage_account_name}")
      end

      i = 0
      until storage_account_created?(storage_account_name) do 
        if(i >= 10) 
          OOLog.fatal("***FAULT:FATAL=Timeout. Could not find storage account #{storage_account_name}")
        end
        i += 1
        sleep 30
      end
        
      OOLog.info("ImageID: #{node['image_id']}")

      # image_id is expected to be in this format; Publisher:Offer:Sku:Version (ie: OpenLogic:CentOS:6.6:latest)
      imageID = node['image_id'].split(':')

      # build storage profile to add to the params for the vm
      storage_profile = Azure::ARM::Compute::Models::StorageProfile.new
      storage_profile.image_reference = Azure::ARM::Compute::Models::ImageReference.new
      storage_profile.image_reference.publisher = imageID[0]
      storage_profile.image_reference.offer = imageID[1]
      storage_profile.image_reference.sku = imageID[2]
      storage_profile.image_reference.version = imageID[3]
      OOLog.info("Image Publisher is: #{storage_profile.image_reference.publisher}")
      OOLog.info("Image Sku is: #{storage_profile.image_reference.sku}")
      OOLog.info("Image Offer is: #{storage_profile.image_reference.offer}")
      OOLog.info("Image Version is: #{storage_profile.image_reference.version}")

      image_version_ref = storage_profile.image_reference.offer+"-"+(storage_profile.image_reference.version).to_s
      msg = "***RESULT:Server_Image_Name=#{image_version_ref}"
      OOLog.info(msg)

      server_name = node['server_name']
      OOLog.info("Server Name: #{server_name}")

      storage_profile.os_disk = Azure::ARM::Compute::Models::OSDisk.new
      storage_profile.os_disk.name = "#{server_name}-disk"
      OOLog.info("Disk Name is: '#{storage_profile.os_disk.name}' ")

      storage_profile.os_disk.vhd = Azure::ARM::Compute::Models::VirtualHardDisk.new
      storage_profile.os_disk.vhd.uri = "https://#{storage_account_name}.blob.core.windows.net/vhds/#{storage_account_name}-#{server_name}.vhd"
      OOLog.info("VHD URI is: #{storage_profile.os_disk.vhd.uri}")
      storage_profile.os_disk.caching = Azure::ARM::Compute::Models::CachingTypes::ReadWrite
      storage_profile.os_disk.create_option = Azure::ARM::Compute::Models::DiskCreateOptionTypes::FromImage


      storage_profile
    end

private

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
            @storage_client.storage_accounts.check_name_availability(params)
       rescue  MsRestAzure::AzureOperationError => e
         OOLog.info("ERROR checking availability of #{storage_account_name}")
         OOLog.info("ERROR Body: #{e.body}")
         return nil
       rescue => ex
         OOLog.fatal("Error checking availability of #{storage_account_name}: #{ex.message}")
      end

      OOLog.info("Storage Name Available: #{response.name_available}")
      response.name_available
    end

    def storage_account_created?(storage_account_name)
      begin
         response =
            @storage_client.storage_accounts.get_properties(@resource_group_name, storage_account_name)
                  OOLog.info("Storage Account Provisioning State: #{response.provisioning_state}")
       rescue  MsRestAzure::AzureOperationError => e
         OOLog.info("#ERROR Body: #{e.body}")
         return false
       rescue => ex
         OOLog.fatal("Error getting properties of #{storage_account_name}: #{ex.message}")
      end

      response.provisioning_state == 'Succeeded'
    end

    def create_storage_account(storage_account_name, account_type)
      # Create a model for new storage account.

      params = Azure::ARM::Storage::Models::StorageAccountCreateParameters.new
      params.kind = Azure::ARM::Storage::Models::Kind::Storage
      params.sku = account_type
      params.location = @location

      Chef::Log.info("Creating Storage Account: [ #{storage_account_name} ] in Resource Group: #{@resource_group_name} ...")
      begin
        start_time = Time.now.to_i
        response =
          @storage_client.storage_accounts.create(@resource_group_name,
                                                  storage_account_name, params)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error creating storage account: #{e.body.values[0]['message']}")
      rescue => ex
        OOLog.fatal("Error creating storage account: #{ex.message}")
      end

      Chef::Log.info("Storage Account created in #{duration} seconds")
      response
    end

  end
end
