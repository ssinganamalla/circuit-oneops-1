require 'fog/azurerm'
require ::File.expand_path('../../azure_base/libraries/logger', __FILE__)

class TrafficManagers
  attr_accessor :traffic_manager_service

  def initialize(resource_group, profile_name, dns_attributes)
    fail ArgumentError, 'resource_group is nil' if resource_group.nil?
    fail ArgumentError, 'profile_name is nil' if profile_name.nil?

    @resource_group_name = resource_group
    @profile_name = profile_name
    @traffic_manager_service = Fog::TrafficManager::AzureRM.new(
      tenant_id: dns_attributes['tenant_id'],
      client_id: dns_attributes['client_id'],
      client_secret: dns_attributes['client_secret'],
      subscription_id: dns_attributes['subscription']
    )
  end

  def create_update_profile(traffic_manager)
    begin
      traffic_manager_profile = @traffic_manager_service.traffic_manager_profiles.create(
        name: @profile_name,
        resource_group: @resource_group_name,
        traffic_routing_method: traffic_manager.routing_method,
        relative_name: traffic_manager.dns_config.relative_name,
        ttl: traffic_manager.dns_config.ttl,
        protocol: traffic_manager.monitor_config.protocol,
        port: traffic_manager.monitor_config.port,
        path: traffic_manager.monitor_config.path
      )
    rescue => e
      Chef::Log.warn("Response traffic_manager create_update_profile status code - #{e.response.code}")
      Chef::Log.warn("Response - #{e.response}")
      return e.response.code
    end
    Chef::Log.info("Response traffic_manager create_update_profile status code - #{response.code}")
    Chef::Log.info("Response - #{response}")
    traffic_manager_profile
  end

  def delete_profile
    traffic_manager_profile = get_profile
    unless traffic_manager_profile.nil?
      begin
        response = traffic_manager_profile.destroy
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("FATAL ERROR deleting Traffic Manager Profile....: #{e.body}")
      rescue => e
        OOLog.fatal("Traffic Manager deleting error....: #{e.body}")
      end
      OOLog.info("Traffic Manager Profile #{@profile_name} deleted successfully!")
      return response
    end
    OOLog.fatal('Traffic Manager Profile does not exist')
  end

  def get_profile
    begin
      traffic_manager_profile = @traffic_manager_service.traffic_manager_profiles.get(@resource_group_name, @profile_name)
    rescue => e
      Chef::Log.warn("Response traffic_manager get_profile status code - #{e.response.code}")
      Chef::Log.warn("Response - #{e.response}")
      return e.response.code
    end
    Chef::Log.info("Response traffic_manager get_profile status code - #{response.code}")
    Chef::Log.info("Response - #{response}")
    traffic_manager_profile
  end
end
