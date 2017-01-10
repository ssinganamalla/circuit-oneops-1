class EndPoint
  module Status
    ENABLED = 'Enabled'
    DISABLED = 'Disabled'
  end

  TYPE = 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'

  def initialize(name, target, location)
    fail ArgumentError, 'name is nil' if name.nil?
    fail ArgumentError, 'target is nil' if target.nil?
    fail ArgumentError, 'location is nil' if location.nil?

    @name = name
    @type = TYPE
    @target = target
    @location = location
  end

  attr_reader :name, :target, :location

  def set_endpoint_status(endpoint_status)
    @endpoint_status = endpoint_status
  end

  def set_weight(weight)
    @weight = weight
  end

  def set_priority(priority)
    @priority = priority
  end

  attr_reader :endpoint_status, :weight, :priority
end