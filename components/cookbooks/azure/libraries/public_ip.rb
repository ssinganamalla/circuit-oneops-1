# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # this class should contain methods to manipulate public ip address
  # within Azure.
  class PublicIp
    attr_accessor :location
    attr_reader :creds, :subspriction

    def initialize(credentials, subscription_id)
      @creds = credentials
      @subscription = subscription_id
      @client = Azure::ARM::Network::NetworkManagementClient.new(credentials)
      @client.subscription_id = subscription_id
    end

    # this will build the public_ip object to be used for creating a public
    # ip in azure
    def build_public_ip_object(ci_id)
      public_ip_address = Azure::ARM::Network::Models::PublicIPAddress.new
      public_ip_address.public_ipallocation_method = Azure::ARM::Network::Models::IPAllocationMethod::Dynamic
      public_ip_address.location = @location
      public_ip_address.name = Utils.get_component_name('publicip', ci_id)
      OOLog.info("Public IP name is: #{public_ip_address.name}")
      public_ip_address
    end

    # this fuction gets the public ip from azure for the given
    # resource group and pip name
    def get(resource_group_name, public_ip_name)
      begin
        OOLog.info("Fetching public IP '#{public_ip_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        response = @client.public_ipaddresses.get(resource_group_name, public_ip_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}, Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}, Exception: #{e.message}")
      end
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this function deletes the public ip
    def delete(resource_group_name, public_ip_name)
      begin
        OOLog.info("Deleting public IP '#{public_ip_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        response = @client.public_ipaddresses.delete(resource_group_name, public_ip_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting PublicIP '#{public_ip_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Error deleting PublicIP '#{public_ip_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.message}")
      end
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this function creates or updates the public ip address
    # it expects the resource group, name of the pip and public ip object
    # to already be created.
    def create_update(resource_group_name, public_ip_name, public_ip_address)
      begin
        OOLog.info("Creating/Updating public IP '#{public_ip_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        response = @client.public_ipaddresses.create_or_update(resource_group_name, public_ip_name, public_ip_address)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => ex
        OOLog.fatal("Exception trying to create/update public ip #{public_ip_address.name} from resource group: #{resource_group_name}.  Exception: #{ex.body}")
      rescue => e
        OOLog.fatal("Exception trying to create/update public ip #{public_ip_address.name} from resource group: #{resource_group_name}.  Exception: #{e.message}")
      end
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this fuction checks whether the public ip belongs to the given
    # resource group
    def check_existence_publicip(resource_group_name, public_ip_name)
      begin
        OOLog.info("Checking existance of public IP '#{public_ip_name}' in '#{resource_group_name}' ")
        start_time = Time.now.to_i
        @client.public_ipaddresses.get(resource_group_name, public_ip_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("Azure::PublicIp - Exception is: #{e.body}")
        if e.body.values[0]['code'] == 'ResourceNotFound'
          return false
        else
          return true
        end
      rescue => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}. Exception: #{e.message}")
      end
      OOLog.info("operation took #{duration} seconds")
      true
    end
  end
end
