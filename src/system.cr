require "./service"
require "./system/*"

module System
  def self.tcp_port_available?(port_num : Int32) : Int32?
    TCPServer.new(port_num).close
    port_num
  rescue ex : Errno
  end

  def self.udp_port_available?(port_num : Int32) : Int32?
    udp_ipv4_port_available(port_num) || udp_ipv6_port_available(port_num)
  end

  def self.udp_ipv4_port_available?(port_num : Int32) : Int32?
    sock = UDPSocket.new Socket::Family::INET
    sock.bind "127.0.0.1", port_num
    sock.close
    port_num
  rescue ex : Errno
  end

  def self.udp_ipv6_port_available?(port_num : Int32) : Int32?
    sock = UDPSocket.new Socket::Family::INET6
    sock.bind "::1", port_num
    sock.close
    port_num
  rescue ex : Errno
  end

  # Returns an available port
  def self.available_port(port = 0) : Int32
    Log.info "checking ports availability", port.to_s
    ports_used = Array(Int32).new
    (port..UInt16::MAX).each do |port|
      if tcp_port_available? port
        Log.warn "ports unavailable", ports_used.join ", " if !ports_used.empty?
        return port
      end
      ports_used << port
    end
    raise "the limit of #{Int16::MAX} for port numbers is reached, no ports available"
  end
end
