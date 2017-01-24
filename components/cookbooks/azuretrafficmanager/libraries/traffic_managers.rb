require 'fog/azurerm'
require 'chef'
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)

# Cookbook Name:: azuretrafficmanager
class TrafficManagers
  attr_accessor :traffic_manager_service

  def initialize(resource_group, profile_name, dns_attributes)
    raise ArgumentError, 'resource_group is nil' if resource_group.nil?
    raise ArgumentError, 'profile_name is nil' if profile_name.nil?

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
        next if endpoint.nil?
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
    serialized_array
  end

  def initialize_traffic_manager(public_ip_fqdns, dns_attributes, gdns_attributes)
    endpoints = initialize_endpoints(public_ip_fqdns)
    dns_config = initialize_dns_config(dns_attributes, gdns_attributes)
    monitor_config = initialize_monitor_config
    traffic_routing_method = gdns_attributes['traffic-routing-method']
    TrafficManager.new(traffic_routing_method, dns_config, monitor_config, endpoints)
  end

  def initialize_endpoints(targets)
    endpoints = []
    for i in 0..targets.length-1
      location = targets[i].split('.').reverse[3]
      endpoint_name = 'endpoint_' + location + '_' + i.to_s
      endpoint = EndPoint.new(endpoint_name, targets[i], location)
      endpoint.set_endpoint_status(EndPoint::Status::ENABLED)
      endpoint.set_weight(1)
      endpoint.set_priority(i + 1)
      endpoints.push(endpoint)
    end
    endpoints
  end

  def initialize_dns_config(dns_attributes, gdns_attributes)
    domain = dns_attributes['zone']
    domain_without_root = domain.split('.').reverse.join('.').partition('.').last.split('.').reverse.join('.')
    subdomain = node['workorder']['payLoad']['Environment'][0]['ciAttributes']['subdomain']
    dns_name = if !subdomain.empty?
                 subdomain + '.' + domain_without_root
               else
                 domain_without_root
               end
    relative_dns_name = dns_name.tr('.', '-').slice!(0, 60)
    Chef::Log.info('The Traffic Manager FQDN is ' + relative_dns_name)
    display_traffic_manager_fqdn(relative_dns_name)

    dns_ttl = gdns_attributes['ttl']
    DnsConfig.new(relative_dns_name, dns_ttl)
  end

  def initialize_monitor_config
    listeners = node.workorder.payLoad.lb[0][:ciAttributes][:listeners]
    protocol = listeners.tr('[]"', '').split(' ')[0].upcase

    monitor_port = listeners.tr('[]"', '').split(' ')[1]
    monitor_path = '/'
    MonitorConfig.new(protocol, monitor_port, monitor_path)
  end

  def display_traffic_manager_fqdn(dns_name)
    fqdn = dns_name + '.' + 'trafficmanager.net'
    ip = ''
    entries = []
    entries.push(name: fqdn, values: ip)
    entries_hash = {}
    entries.each do |entry|
      key = entry[:name]
      entries_hash[key] = entry[:values]
    end
    node.set[:entries] = entries
    puts "***RESULT:entries=#{JSON.dump(entries_hash)}"
  end

  def get_traffic_manager_resource_group(resource_group_names, profile_name, dns_attributes)
    resource_group_names.each do |resource_group_name|
      traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, dns_attributes)
      Chef::Log.info('Checking traffic manager FQDN set in resource group: ' + resource_group_name)
      profile = traffic_manager_processor.get_profile
      return resource_group_name unless profile.nil?
    end
    nil
  end
end
