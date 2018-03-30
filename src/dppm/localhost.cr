require "socket"
require "exec"

struct Localhost
  class_getter proc_ver : Array(String) = File.read("/proc/version").split(' ')
  class_getter kernel : String = proc_ver[0].downcase
  class_getter kernel_ver : String = proc_ver[2].split('-')[0]
  class_getter sysinit : String = get_sysinit
  class_getter arch : String = get_arch
  class_getter vars : Hash(String, String) = get_vars
  class_getter service : Service::Systemd | Service::OpenRC = get_service

  def self.get_service
    case sysinit
    when "systemd" then Service::Systemd
    when "openrc"  then Service::OpenRC
    else
      raise "unsupported init system"
    end
  end

  # All system environment variables
  private def self.get_vars
    {% begin %}
    {
      {% for var in %w(arch kernel kernel_ver sysinit) %}
        {{var}} => {{var.id}},
      {% end %}
    }
    {% end %}
  end

  private def self.get_arch
    case File.read "/proc/kallsyms"
    when .includes? " x86_64_"  then "x86-64"
    when .includes? " x86_"     then "x86"
    when .includes? " aarch64_" then "aarch64"
    when .includes? " armv7_"   then "armhf"
    else
      raise "unsupported architecure: "
    end
  end

  private def self.get_sysinit
    init = File.basename File.real_path "/sbin/init"
    case init
    when "systemd", "init" then init
    else
      raise "unsupported init system, consider to migrate to OpenRC if you are still in init.d: " + init
    end
  end

  def self.port(port_num : Int32, port_used = Array(Int32).new, &log : String, String, String -> Nil)
    raise "the limit of 65535 for port numbers is reached" if port_num > 65535
    begin
      # tcp port available?
      TCPServer.new(port_num).close
      # ipv4 udp port available?
      ip4 = UDPSocket.new Socket::Family::INET
      ip4.bind "127.0.0.1", port_num
      ip4.close
      # ipv6 udp port available?
      ip6 = UDPSocket.new Socket::Family::INET6
      ip6.bind "::1", port_num
      ip6.close
      yield "WARN", "ports unavailable or used", port_used.join ", " if !port_used.empty?
      port_num
    rescue
      port port_num + 1, port_used << port_num, &log
    end
  end
end
