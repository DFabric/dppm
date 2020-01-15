require "socket"

# Creates local Sockets to know local available ports.
struct PortChecker
  property tcp : Bool
  property udp : Bool
  getter ipaddress : Socket::IPAddress

  def address=(host : String)
    @ipaddress = address_normalizer host
  end

  def initialize(host : String, @tcp : Bool = false, @udp : Bool = false)
    @ipaddress = address_normalizer host
  end

  private def address_normalizer(host : String) : Socket::IPAddress
    Socket::IPAddress.new host.lchop('[').rchop(']'), 1
  end

  # Returns an available port.
  def available_port?(port : Int32) : Bool
    if @tcp
      socket = TCPSocket.new @ipaddress.family
      return false if !internal_available_port? socket, port
    end
    if @udp
      socket = UDPSocket.new @ipaddress.family
      return false if !internal_available_port? socket, port
    end

    true
  end

  private def internal_available_port?(socket : IPSocket, port : Int32) : Bool
    socket.bind @ipaddress.address, port
    available = true
  rescue ex : Errno
    available = false
  ensure
    socket.close
    available
  end

  # Returns the first available port.
  def first_available_port(start_port : Int32 = @ipaddress.port) : Int32?
    (start_port..UInt16::MAX).each do |port|
      return port if available_port? port
    end
  end
end
