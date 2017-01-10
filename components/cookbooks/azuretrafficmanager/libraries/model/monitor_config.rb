class MonitorConfig
  module Protocol
    HTTP = 'HTTP'
    HTTPS = 'HTTPS'
  end

  def initialize(protocol, port, path)
    fail ArgumentError, 'protocol is nil' if protocol.nil?
    fail ArgumentError, 'port is nil' if port.nil?
    fail ArgumentError, 'path is nil' if path.nil?

    @protocol = protocol
    @port = port
    @path = path
  end

  attr_reader :protocol, :port, :path
end