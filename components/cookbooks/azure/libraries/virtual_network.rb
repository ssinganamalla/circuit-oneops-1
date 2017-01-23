require 'fog/azurerm'
require 'chef'

require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)


# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # Class that defines the functions for manipulating virtual networks in Azure
  class VirtualNetwork
    attr_accessor :location,
                  :name,
                  :address,
                  :sub_address,
                  :dns_list,
                  :network_client
    attr_reader :creds, :subscription

    def initialize(creds, subscription)
      @creds = creds
      tenant_id = creds[:tenant_id]
      client_secret = creds[:client_secret]
      client_id = creds[:client_id]
      @subscription = subscription
      @network_client = Fog::Network::AzureRM.new(client_id: client_id, client_secret: client_secret, tenant_id: tenant_id, subscription_id: subscription)
    end

    # this method creates the vnet object that is later passed in to create
    # the vnet
    def build_network_object
      OOLog.info("network_address: #{@address}")

      ns_list = []
      @dns_list.each do |dns_list|
        OOLog.info('dns address[' + @dns_list.index(dns_list).to_s + ']: ' + dns_list.strip)
        ns_list.push(dns_list.strip)
      end

      subnet = AzureNetwork::Subnet.new(@creds, @subscription)
      subnet.sub_address = @sub_address
      subnet.name = @name
      sub_nets = subnet.build_subnet_object

      virtual_network = Fog::Network::AzureRM::VirtualNetwork.new
      virtual_network.location = @location
      virtual_network.address_prefixes = [@address]
      virtual_network.dns_servers = ns_list unless ns_list.nil?
      virtual_network.subnets = sub_nets
      virtual_network
    end

    # this will create/update the vnet
    def create_update(resource_group_name, virtual_network)
      OOLog.info("Creating Virtual Network '#{@name}' ...")
      start_time = Time.now.to_i
      array_of_subnets = get_array_of_subnet_hashes(virtual_network.subnets)

      begin
        response = @network_client.virtual_networks.create(name: @name,
                                                           location: virtual_network.location,
                                                           resource_group: resource_group_name,
                                                           subnets: array_of_subnets,
                                                           dns_servers: virtual_network.dns_servers,
                                                           address_prefixes: virtual_network.address_prefixes)

      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{e.body}")
      rescue => ex
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info('Successfully created/updated network name: ' + @name + "\nOperation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def get(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?
      OOLog.info("Getting Virtual Network '#{@name}' ...")
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks.get(resource_group_name, @name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the resource group
    def list(resource_group_name)
      OOLog.info("Getting vnets from Resource Group '#{resource_group_name}' ...")
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks(resource_group: resource_group_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the subscription
    def list_all
      OOLog.info('Getting subscription vnets ...')
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def exists?(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?
      OOLog.info("Checking if Virtual Network '#{@name}' Exists! ...")
      begin
        result = @network_client.virtual_networks.check_virtual_network_exists(resource_group_name, @name)
        puts "Result of vnet: #{result}"
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end
      result
    end

    def get_subnet_with_available_ips(subnets, express_route_enabled)
      puts "Subnets: #{subnets.inspect}"
      subnets.each do |subnet|
        Chef::Log.info('checking for ip availability in ' + subnet.name)
        address_prefix = subnet.address_prefix

        if express_route_enabled == true
          total_num_of_ips_possible = (2**(32 - address_prefix.split('/').last.to_i)) - 5 # Broadcast(1)+Gateway(1)+azure express routes(3) = 5
        else
          total_num_of_ips_possible = (2**(32 - address_prefix.split('/').last.to_i)) - 2 # Broadcast(1)+Gateway(1)
        end
        Chef::Log.info("Total number of ips possible is: #{total_num_of_ips_possible}")

        no_ips_inuse = subnet.ip_configurations.nil? ? 0 : subnet.ip_configurations.length
        Chef::Log.info("Num of ips in use: #{no_ips_inuse}")

        remaining_ips = total_num_of_ips_possible - no_ips_inuse
        if remaining_ips.zero?
          Chef::Log.info("No IP address remaining in the Subnet '#{subnet.name}'")
          Chef::Log.info("Total number of subnets(subnet_name_list.count) = #{subnets.count}")
          Chef::Log.info('checking the next subnet')
          next # check the next subnet
        else
          return subnet
        end
      end

      Chef::Log.error('***FAULT:FATAL=- No IP address available in any of the Subnets allocated. limit exceeded')
      exit 1
    end

    private

    def get_array_of_subnet_hashes(array_of_subnet_objs)
      subnets_array = []
      array_of_subnet_objs.each do |subnet|
        hash = {}
        subnet.instance_variables.each { |attr| hash[attr.to_s.delete('@')] = subnet.instance_variable_get(attr) }
        unless hash['attributes'].nil?
          subnets_array << hash['attributes']
        end
      end
      subnets_array
    end
  end # end of class
end
