class DnsConfig

  def initialize(relative_name, ttl)
    fail ArgumentError, 'relative_name is nil' if relative_name.nil?
    fail ArgumentError, 'ttl is nil' if ttl.nil?

    @relative_name = relative_name
    @ttl = ttl
  end

  attr_reader :relative_name, :ttl
end