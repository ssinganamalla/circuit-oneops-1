# AzureCompute module for classes that are used in the compute step.
module AzureCompute
  # Class for all things Availability Sets that we do in OneOps for Azure.
  # get, add, delete, etc.
  class AvailabilitySet
    def initialize(compute_service)
      creds =
        Utils.get_credentials(compute_service['tenant_id'],
                              compute_service['client_id'],
                              compute_service['client_secret']
                             )

      @client = Azure::ARM::Compute::ComputeManagementClient.new(creds)
      @client.subscription_id = compute_service['subscription']
    end

    # method will get the availability set using the resource group and
    # availability set name
    # will return whether or not the availability set exists.
    def get(resource_group, availability_set)
      begin
          @client.availability_sets.get(resource_group,
                                        availability_set)
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
    def add(resource_group, availability_set, location)
      # check if it exists
      existance_promise = get(resource_group, availability_set)
      if !existance_promise.nil?
        OOLog.info("Availability Set #{existance_promise.name} exists
                        in the #{existance_promise.location} region.")
      else
        # need to create the availability set
        OOLog.info("Creating Availability Set
                      '#{availability_set}' in #{location} region")
        avail_set = get_avail_set_props(location)
        begin
          start_time = Time.now.to_i
          @client.availability_sets.create_or_update(resource_group,
                                                     availability_set,
                                                     avail_set)
          end_time = Time.now.to_i
          duration = end_time - start_time
        rescue MsRestAzure::AzureOperationError => e
          OOLog.fatal("Error adding an availability set: #{e.body}")
        rescue => ex
          OOLog.fatal("Error adding an availability set: #{ex.message}")
        end

        OOLog.info("Availability Set created in #{duration} seconds")
      end
    end

    private

    # create the properties object for creating availability sets
    def get_avail_set_props(location)
      avail_set =
          Azure::ARM::Compute::Models::AvailabilitySet.new
      # At least two domain faults
      avail_set.platform_fault_domain_count = 2
      avail_set.platform_update_domain_count = 2
      # At this point we do not have virtual machines to include
      avail_set.virtual_machines = []
      avail_set.statuses = []
      avail_set.location = location
      avail_set
    end
  end
end
