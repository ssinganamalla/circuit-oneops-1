class TrafficManager
  module ProfileStatus
    ENABLED = 'Enabled'
    DISABLED = 'Disabled'
  end

  module RoutingMethod
    PERFORMANCE = 'Performance'
    WEIGHTED = 'Weighted'
    PRIORITY = 'Priority'
  end

  GLOBAL = 'global'

  def initialize(routing_method, dns_config, monitor_config, endpoints)
    fail ArgumentError, 'routing_method is nil' if routing_method.nil?
    fail ArgumentError, 'dns_config is nil' if dns_config.nil?
    fail ArgumentError, 'monitor_config is nil' if monitor_config.nil?
    fail ArgumentError, 'endpoints is nil' if endpoints.nil?

    @routing_method = routing_method
    @dns_config = dns_config
    @monitor_config = monitor_config
    @endpoints = endpoints
    @profile_status = ProfileStatus::ENABLED
    @location = GLOBAL
  end

  attr_reader :routing_method, :dns_config, :monitor_config, :profile_status, :location, :endpoints

  def set_profile_status=(profile_status)
    @profile_status = profile_status
  end
end

