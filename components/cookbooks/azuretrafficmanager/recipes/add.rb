require File.expand_path('../../libraries/traffic_managers.rb', __FILE__)
require File.expand_path('../../libraries/model/traffic_manager.rb', __FILE__)
require File.expand_path('../../libraries/model/dns_config.rb', __FILE__)
require File.expand_path('../../libraries/model/monitor_config.rb', __FILE__)
require File.expand_path('../../libraries/model/endpoint.rb', __FILE__)
require File.expand_path('../../../azure_lb/libraries/load_balancer.rb', __FILE__)
require File.expand_path('../../../azure/libraries/public_ip.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require 'chef'
require 'azure_mgmt_network'

::Chef::Recipe.send(:include, Utils)
::Chef::Recipe.send(:include, AzureNetwork)

def get_public_ip_fqdns(cred_hash, resource_group_names, ns_path_parts)
  platform_name = ns_path_parts[5]
  plat_name = platform_name.gsub(/-/, '').downcase
  load_balancer_name = "lb-#{plat_name}"
  public_ip_fqdns = []
  # credentials = Utils.get_credentials(dns_attributes['tenant_id'], dns_attributes['client_id'], dns_attributes['client_secret'])
  lb = AzureNetwork::LoadBalancer.new(cred_hash)
  pip = AzureNetwork::PublicIp.new(cred_hash)

  resource_group_names.each do |resource_group_name|
    load_balancer = lb.get(resource_group_name, load_balancer_name)
    next if load_balancer.nil?

    public_ip_id = load_balancer.frontend_ip_configurations[0].public_ipaddress_id
    public_ip_name = public_ip_id.split('/')[8]
    public_ip = pip.get(resource_group_name, public_ip_name)
    public_ip_fqdn = public_ip.fqdn
    Chef::Log.info('Obtained public ip fqdn ' + public_ip_fqdn + ' to be used as endpoint for traffic manager')
    public_ip_fqdns.push(public_ip_fqdn)
  end
  public_ip_fqdns
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

def initialize_traffic_manager(public_ip_fqdns, dns_attributes, gdns_attributes)
  endpoints = initialize_endpoints(public_ip_fqdns)
  dns_config = initialize_dns_config(dns_attributes, gdns_attributes)
  monitor_config = initialize_monitor_config
  traffic_routing_method = gdns_attributes['traffic-routing-method']
  TrafficManager.new(traffic_routing_method, dns_config, monitor_config, endpoints)
end

def get_resource_group_names
  ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
  org = ns_path_parts[1]
  assembly = ns_path_parts[2]
  environment = ns_path_parts[3]

  resource_group_names = []
  remotegdns_list = node['workorder']['payLoad']['remotegdns']
  remotegdns_list.each do |remotegdns|
    location = remotegdns['ciAttributes']['location']
    resource_group_name = org[0..15] + '-' + assembly[0..15] + '-' + node.workorder.box.ciId.to_s + '-' + environment[0..15] + '-' + Utils.abbreviate_location(location)
    resource_group_names.push(resource_group_name)
  end
  Chef::Log.info('remotegdns resource groups: ' + resource_group_names.to_s)
  resource_group_names
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
#################################################
#                                               #
#################################################

# set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
cloud_name = node['workorder']['cloud']['ciName']
dns_attributes = node['workorder']['services']['dns'][cloud_name]['ciAttributes']
gdns_attributes = node['workorder']['services']['gdns'][cloud_name]['ciAttributes']

cred_hash = {
    tenant_id: dns_attributes['tenant_id'],
    client_secret: dns_attributes['client_secret'],
    client_id: dns_attributes['client_id'],
    subscription_id: dns_attributes['subscription']
}

begin
  resource_group_names = get_resource_group_names
  public_ip_fqdns = get_public_ip_fqdns(cred_hash, resource_group_names, ns_path_parts)
  traffic_manager = initialize_traffic_manager(public_ip_fqdns, dns_attributes, gdns_attributes)

  platform_name = ns_path_parts[5]
  profile_name = 'trafficmanager-' + platform_name

  resource_group_name = get_traffic_manager_resource_group(resource_group_names, profile_name, dns_attributes)
  if resource_group_name.nil?
    include_recipe 'azure::get_platform_rg_and_as'
    resource_group_name = node['platform-resource-group']
    traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, cred_hash)
    traffic_manager_profile_result = traffic_manager_processor.create_update_profile(traffic_manager)
    if traffic_manager_profile_result.nil?
      OOLog.fatal("Traffic Manager profile #{profile_name} could not be created")
    end
  else
    traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, cred_hash)
    profile_deleted = traffic_manager_processor.delete_profile
    if profile_deleted
      traffic_manager_profile_result = traffic_manager_processor.create_update_profile(traffic_manager)
      if traffic_manager_profile_result.nil?
        OOLog.fatal("ERROR recreating Traffic Manager profile #{profile_name}")
      end
    else
      Chef::Log.error('Failed to delete traffic manager.')
      exit 1
    end
  end
  Chef::Log.info('Traffic Manager created successfully')
rescue => e
  OOLog.fatal("Error creating Traffic Manager: #{e.message}")
end
