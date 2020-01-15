require "spec"
require "../src/port_checker"

describe PortChecker do
  it "normalizes IPv6 addresses" do
    pc = PortChecker.new "[::1]"
    pc.ipaddress.address.should eq "::1"
  end

  {"127.0.0.1", "::1"}.each do |host|
    {
      PortChecker.new(host, tcp: true),
      PortChecker.new(host, udp: true),
      PortChecker.new(host, tcp: true, udp: true),
    }.each do |pc|
      msg = host
      msg += " TCP" if pc.tcp
      msg += " UDP" if pc.udp
      if !pc.first_available_port
        puts "#{msg} not supported"
        next
      end

      describe msg do
        describe "available port" do
          it "returns true when available" do
            port = pc.first_available_port.as Int32
            pc.available_port?(port).should be_true
          end

          it "returns false when not available" do
            tcp_socket = TCPSocket.new pc.ipaddress.family if pc.tcp
            udp_socket = UDPSocket.new pc.ipaddress.family if pc.udp
            port = pc.first_available_port.as Int32
            begin
              tcp_socket.try &.bind pc.ipaddress.address, port
              udp_socket.try &.bind pc.ipaddress.address, port
              pc.available_port?(port).should be_false
            ensure
              tcp_socket.try &.close
              udp_socket.try &.close
            end
          end
        end

        it "returns the first available port" do
          pc.first_available_port.should be_a Int32
        end
      end
    end
  end
end
