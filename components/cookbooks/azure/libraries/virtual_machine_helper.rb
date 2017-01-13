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
      @location = @compute_service[:location]
      @size_id = node[:size_id]
      @creds = { tenant_id: @compute_service[:tenant_id],
                 client_id: @compute_service[:client_id],
                 client_secret: @compute_service[:client_secret],
                 subscription_id: @compute_service[:subscription] }

      @compute_client = Fog::Compute::AzureRM.new(@creds)
      @storage_profile = AzureCompute::StorageProfile.new(@creds, @resource_group_name, @location, @size_id, @ci_id)
    end

    def check_vm_exists?
      begin
        exists = @compute_client.check_vm_exists?(@resource_group_name, @server_name)
        OOLog.debug("VM Exists?: #{exists}")
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end

    def create_or_update()
      # build hash containing vm info
      # used in Fog::Compute::AzureRM::create_virtual_machine()
      vm_hash = {}

      # common values
      vm_hash[:name] = @server_name
      vm_hash[:resource_group] = @resource_group_name
      vm_hash[:availability_set_id] =
          @compute_client.get_availability_set(node['platform-resource-group'], node['platform-availability-set']).id
      vm_hash[:location] = @compute_service[:location]

      # hardware profile values
      vm_hash[:vm_size] = @size_id

      # storage profile values
      vm_hash[:storage_account_name] = @storage_profile.get_storage_account_name()
      vm_hash[:publisher] = @imageID[0]
      vm_hash[:offer] = @imageID[1]
      vm_hash[:sku] = @imageID[2]
      vm_hash[:version] = @imageID[3]

      # os profile values
      vm_hash[:username] = @compute_service[:initial_user]
      vm_hash[:disable_password_authentication] = true
      vm_hash[:ssh_key_path] = "/home/#{@compute_service[:initial_user]}/.ssh/authorized_keys"
      vm_hash[:ssh_key_data] = @keypair[:ciAttributes][:public]

      # network profile values
      vm_hash[:network_interface_card_id] =

      # create the virtual machine
      begin
        @client.create_virtual_machine(vm_hash)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end
  end
end