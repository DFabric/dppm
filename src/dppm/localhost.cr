require "socket"
require "exec"

struct Localhost
  class_getter proc_ver : Array(String) = File.read("/proc/version").split(' ')
  class_getter kernel : String = proc_ver[0].downcase
  class_getter kernel_ver : String = proc_ver[2].split('-')[0]
  class_getter sysinit : String = service.name
  class_getter arch : String = get_arch
  class_getter vars : Hash(String, String) = get_vars
  class_getter service : Service::Systemd | Service::OpenRC = get_sysinit

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
      Log.error "unsupported architecure: "
    end
  end

  private def self.get_sysinit
    init = File.basename File.real_path "/sbin/init"
    if init == "systemd"
      Service::Systemd
    elsif File.exists? "/sbin/openrc"
      Service::OpenRC
    else
      Log.error "unsupported init system, consider to migrate to OpenRC if you are still in init.d: " + init
    end
  end

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
end
