require 'fog/azurerm'
require 'chef'
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)

class TrafficManagers
  attr_accessor :traffic_manager_service

  def initialize(resource_group, profile_name, dns_attributes)
    fail ArgumentError, 'resource_group is nil' if resource_group.nil?
    fail ArgumentError, 'profile_name is nil' if profile_name.nil?

    @resource_group_name = resource_group
    @profile_name = profile_name
    @traffic_manager_service = Fog::TrafficManager::AzureRM.new(
      tenant_id: dns_attributes[:tenant_id],
      client_id: dns_attributes[:client_id],
      client_secret: dns_attributes[:client_secret],
      subscription_id: dns_attributes[:subscription]
    )
  end

  def create_update_profile(traffic_manager)
    begin
      traffic_manager_profile = @traffic_manager_service.traffic_manager_profiles.create(
        name: @profile_name,
        resource_group: @resource_group_name,
        location: traffic_manager.location,
        profile_status: traffic_manager.profile_status,
        endpoints: serialize_endpoints(traffic_manager.endpoints),
        traffic_routing_method: traffic_manager.routing_method,
        relative_name: traffic_manager.dns_config.relative_name,
        ttl: traffic_manager.dns_config.ttl,
        protocol: traffic_manager.monitor_config.protocol,
        port: traffic_manager.monitor_config.port,
        path: traffic_manager.monitor_config.path
      )
    rescue => e
      OOLog.fatal("Response traffic_manager create_update_profile - #{e.message}")
    end
    OOLog.info("Response traffic_manager create_update_profile - #{traffic_manager_profile}")
    traffic_manager_profile
  end

  def delete_profile
    begin
      response = get_profile.destroy
    rescue MsRestAzure::AzureOperationError => e
      OOLog.fatal("FATAL ERROR deleting Traffic Manager Profile....: #{e.body}")
    rescue => e
      OOLog.fatal("Traffic Manager deleting error....: #{e.body}")
    end
    OOLog.info("Traffic Manager Profile #{@profile_name} deleted successfully!")
    response
  end

  def get_profile
    begin
      traffic_manager_profile = @traffic_manager_service.traffic_manager_profiles.get(@resource_group_name, @profile_name)
    rescue => e
      Chef::Log.warn("Response traffic_manager get_profile - #{e.message}")
      return nil
    end
    Chef::Log.info("Response traffic_manager get_profile - #{traffic_manager_profile}")
    traffic_manager_profile
  end

  private

  def serialize_endpoints(endpoints)
    serialized_array = []
    unless endpoints.nil?
      endpoints.each do |endpoint|
        unless endpoint.nil?
          element = {
            name: endpoint.name,
            traffic_manager_profile_name: @profile_name,
            resource_group: @resource_group_name,
            type: endpoint.type,
            target: endpoint.target,
            endpoint_location: endpoint.location,
            endpoint_status: endpoint.endpoint_status,
            priority: endpoint.priority,
            weight: endpoint.weight
          }
          serialized_array.push(element)
        end
      end
    end
    serialized_array
  end
end
