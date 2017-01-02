require 'azure_mgmt_compute'
require 'fog/azurerm'
require File.expand_path('../../libraries/resource_group_manager.rb', __FILE__)

require File.expand_path('../../libraries/logger.rb', __FILE__)
require File.expand_path('../../libraries/utils.rb', __FILE__)

::Chef::Recipe.send(:include, Azure::ARM::Compute)
::Chef::Recipe.send(:include, Azure::ARM::Compute::Models)

module AzureBase
  # Add/Get/Delete operations of availability set
  class AvailabilitySetManager < AzureBase::ResourceGroupManager
    attr_accessor :as_name

    def initialize(node)
      super(node)
      # set availability set name same as resource group name
      @as_name = @rg_name
      @resource_client = Fog::Compute::AzureRM.new(client_id: @client, client_secret: @client_secret, tenant_id: @tenant, subscription_id: @subscription)
    end

    # method will get the availability set using the resource group and
    # availability set name
    # will return whether or not the availability set exists.
    def get
      begin
        @resource_client.availability_sets.get(@rg_name, @as_name)
      rescue MsRestAzure::AzureOperationError => e
        # if the error is that the availability set doesn't exist,
        # just return a nil
        if e.response.status == 404
          puts 'Availability Set Not Found!  Create It!'
          return nil
        end
        OOLog.fatal("Error getting availability set: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting availability set: #{ex.message}")
      end
    end

    # this method will add the availability set if needed.
    # it first checks to make sure the availability set exists,
    # if not, it will create it.
    def add
      # check if it exists
      # as = get
      as = nil
      if !as.nil?
        OOLog.info("Availability Set #{as.name} exists in the #{as.location} region.")
      else
        # need to create the availability set
        OOLog.info("Creating Availability Set
                      '#{@as_name}' in #{@location} region")

        begin
          @resource_client.availability_sets.create(resource_group: @rg_name, name: @as_name, location: @location)
        rescue MsRestAzure::AzureOperationError => e
          OOLog.fatal("Error adding an availability set: #{e.body}")
        rescue => ex
          OOLog.fatal("Error adding an availability set: #{ex.message}")
        end
      end
    end

    private

    # create the properties object for creating availability sets
    def get_avail_set
      avail_set =
        Azure::ARM::Compute::Models::AvailabilitySet.new
      # At least two domain faults
      avail_set.platform_fault_domain_count = 2
      avail_set.platform_update_domain_count = 2
      # At this point we do not have virtual machines to include
      avail_set.virtual_machines = []
      avail_set.statuses = []
      avail_set.location = @location
      avail_set
    end
  end
end
