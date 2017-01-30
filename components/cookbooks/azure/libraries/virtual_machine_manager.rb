module AzureCompute
  class VirtualMachineManager
    attr_accessor :compute_service,
                  :initial_user,
                  :private_ip,
                  :ip_type,
                  :compute_ci_id,
                  :token

    def initialize(node)
      @cloud_name = node['workorder']['cloud']['ciName']
      @compute_service =
        node['workorder']['services']['compute'][@cloud_name]['ciAttributes']
      @keypair_service = node['workorder']['payLoad']['SecuredBy'].first
      @server_name = node['server_name']
      @resource_group_name = node['platform-resource-group']
      @location = @compute_service[:location]
      @initial_user = @compute_service[:initial_user]
      @express_route_enabled = @compute_service['express_route_enabled']
      @secgroup_name = node['workorder']['payLoad']['DependsOn'][0]['ciName']
      @imageID = node['image_id'].split(':')
      @platform = node['platform']
      @size_id = node[:size_id]
      @ip_type = node['ip_type']
      @platform_ci_id = node['workorder']['box']['ciId']
      @compute_ci_id = node['workorder']['rfcCi']['ciId']

      @creds = { tenant_id: @compute_service[:tenant_id],
                 client_id: @compute_service[:client_id],
                 client_secret: @compute_service[:client_secret],
                 subscription_id: @compute_service[:subscription] }

      @compute_client = Fog::Compute::AzureRM.new(@creds)
      @network_client = Fog::Network::AzureRM.new(@creds)
    end

    def check_vm_exists?
      begin
        exists = @compute_client.servers.check_vm_exists(@resource_group_name, @server_name)
        OOLog.debug("VM Exists?: #{exists}")
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end

    def create_or_update_vm
      OOLog.info('Resource group name: ' + @resource_group_name)

      @ip_type = 'public'
      @ip_type = 'private' if @express_route_enabled
      OOLog.info('ip_type: ' + @ip_type)

      @storage_profile = AzureCompute::StorageProfile.new(@creds)
      @storage_profile.resource_group_name = @resource_group_name
      @storage_profile.location = @location
      @storage_profile.size_id = @size_id
      @storage_profile.ci_id = @platform_ci_id

      @network_profile = AzureNetwork::NetworkInterfaceCard.new(@token, @compute_service[:subscription])
      @network_profile.location = @location
      @network_profile.rg_name = @resource_group_name
      @network_profile.ci_id = @compute_ci_id

      # build hash containing vm info
      # used in Fog::Compute::AzureRM::create_virtual_machine()
      vm_hash = {}

      # common values
      vm_hash[:name] = @server_name
      vm_hash[:resource_group] = @resource_group_name
      vm_hash[:availability_set_id] =
        @compute_client.availability_sets.get(@resource_group_name, @resource_group_name).id
      vm_hash[:location] = @compute_service[:location]

      # hardware profile values
      vm_hash[:vm_size] = @size_id

      # storage profile values
      vm_hash[:storage_account_name] = @storage_profile.get_storage_account_name
      vm_hash[:publisher] = @imageID[0]
      vm_hash[:offer] = @imageID[1]
      vm_hash[:sku] = @imageID[2]
      vm_hash[:version] = @imageID[3]

      # @platform = 'linux' unless @platform =~ /windows/

      vm_hash[:platform] = @platform

      # os profile values
      vm_hash[:username] = @initial_user
      vm_hash[:password] = 'On3oP$'
      vm_hash[:disable_password_authentication] = true
      # vm_hash[:disable_password_authentication] = false
      vm_hash[:ssh_key_data] = @keypair_service[:ciAttributes][:public]

      # network profile values
      vm_hash[:network_interface_card_id] = @network_profile.build_network_profile(@compute_service[:express_route_enabled],
                                                                                   @compute_service[:resource_group],
                                                                                   @compute_service[:network],
                                                                                   @compute_service[:network_address].strip,
                                                                                   (@compute_service[:subnet_address]).split(','),
                                                                                   (@compute_service[:dns_ip]).split(','),
                                                                                   @ip_type,
                                                                                   @secgroup_name)

      @private_ip = @network_profile.private_ip
      # create the virtual machine
      begin
        @compute_client.servers.create(vm_hash)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
      end
    end

    def delete_vm
      OOLog.info('cloud_name is: ' + @cloud_name)
      OOLog.info('Subscription id is: ' + @compute_service[:subscription])
      start_time = Time.now.to_i
      @ip_type = 'public'
      @ip_type = 'private' if @express_route_enabled == 'true'
      OOLog.info('ip_type: ' + @ip_type)
      begin
        vm = @compute_client.servers.get(@resource_group_name, @server_name)
        if vm.nil?
          Chef::Log.info("VM '#{@server_name}' was not found. Nothing to delete. ")
        else
          # retrive the vhd name from the VM properties and use it to delete the associated VHD in the later step.
          vhd_uri = vm.os_disk_vhd_uri
          storage_account = vhd_uri.split('.').first.split('//').last
          datadisk_uri = nil
          datadisk_uri = vm.data_disks[0].vhd_uri if vm.data_disks.count > 0
          Chef::Log.info("Deleting Azure VM: '#{@server_name}'")
          # delete the VM from the platform resource group

          Chef::Log.info('VM is deleted') if vm.destroy

          return storage_account, vhd_uri, datadisk_uri
        end
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{e.body.values[0]['message']}")
      rescue => ex
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{ex.message}")
      ensure
        end_time = Time.now.to_i
        duration = end_time - start_time
        OOLog.info("Deleting VM took #{duration} seconds")
      end
    end
  end
end
