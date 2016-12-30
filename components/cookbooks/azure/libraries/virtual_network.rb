# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # Class that defines the functions for manipulating virtual networks in Azure
  class VirtualNetwork
    attr_accessor :location,
                  :name,
                  :address,
                  :sub_address,
                  :dns_list
    attr_reader :creds, :subscription

    def initialize(creds, subscription)
      @creds = creds
      @subscription = subscription
      @client = Azure::ARM::Network::NetworkManagementClient.new(creds)
      @client.subscription_id = subscription
    end

    # this method creates the vnet object that is later passed in to create
    # the vnet
    def build_network_object
      OOLog.info("network_address: #{@address}")
      address_space = Azure::ARM::Network::Models::AddressSpace.new
      address_space.address_prefixes = [@address]

      ns_list = []
      @dns_list.each do |dns_list|
        OOLog.info('dns address[' + @dns_list.index(dns_list).to_s + ']: ' + dns_list.strip)
        ns_list.push(dns_list.strip)
      end
      dhcp_options = Azure::ARM::Network::Models::DhcpOptions.new

      dhcp_options.dns_servers = ns_list unless ns_list.nil?

      subnet = AzureNetwork::Subnet.new(@creds, @subscription)
      subnet.sub_address = @sub_address
      subnet.name = @name
      sub_nets = subnet.build_subnet_object

      virtual_network = Azure::ARM::Network::Models::VirtualNetwork.new
      virtual_network.location = @location
      virtual_network.address_space = address_space
      virtual_network.dhcp_options = dhcp_options
      virtual_network.subnets = sub_nets

      virtual_network
    end

    # this will create/update the vnet
    def create_update(resource_group_name, virtual_network)
      OOLog.info("Creating Virtual Network '#{@name}' ...")
      begin
        start_time = Time.now.to_i
        response = @client.virtual_networks.create_or_update(resource_group_name, @name, virtual_network)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{e.body}")
      rescue => ex
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{ex.message}")
      end

      OOLog.info('Successfully created/updated network name: ' + @name)
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def get(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?

      OOLog.info("Getting Virtual Network '#{@name}' ...")
      begin
        start_time = Time.now.to_i
        response = @client.virtual_networks.get(resource_group_name, @name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the resource group
    def list(resource_group_name)
      OOLog.info("Getting vnets from Resource Group '#{resource_group_name}' ...")
      begin
        start_time = Time.now.to_i
        response = @client.virtual_networks.list(resource_group_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{ex.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the subscription
    def list_all
      OOLog.info('Getting subscription vnets ...')
      begin
        start_time = Time.now.to_i
        response = @client.virtual_networks.list_all
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{ex.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def exists?(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?

      begin
        OOLog.info("Checking if Virtual Network '#{@name}' Exists! ...")
        @client.virtual_networks.get(resource_group_name, @name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("Exception from Azure: #{e.body}")
        # check the error
        # If the error is that it doesn't exist, return true
        OOLog.info("Error of Exception is: '#{e.body.values[0]}'")
        OOLog.info("Code of Exception is: '#{e.body.values[0]['code']}'")
        if e.body.values[0]['code'] == 'ResourceNotFound'
          OOLog.info('VNET DOES NOT EXIST!!')
          return false
        else
          # for all other errors, throw the exception back
          OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
        end
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end

      OOLog.info('VNET EXISTS!!')
      true
    end
  end # end of class
end
