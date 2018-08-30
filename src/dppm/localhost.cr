require "socket"

struct Localhost
  class_getter proc_ver : Array(String) = File.read("/proc/version").split(' '),
    kernel_ver : String = proc_ver[2].split('-')[0],
    sysinit : String = service.name,
    sysinit_ver : String = service.version.to_s,
    vars : Hash(String, String) = get_vars,
    service : Service::Systemd | Service::OpenRC = get_sysinit

  # System's kernel
  {% if flag?(:linux) %}
    class_getter kernel = "linux"
  {% elsif flag?(:freebsd) %}
    class_getter kernel = "freebsd"
  {% elsif flag?(:openbsd) %}
    class_getter kernel = "openbsd"
  {% else %}
    raise "unsupported system"
  {% end %}

  # Architecture
  {% if flag?(:i686) %}
    class_getter arch = "x86"
  {% elsif flag?(:x86_64) %}
    class_getter arch = "x86-64"
  {% elsif flag?(:arm) %}
    class_getter arch = "armhf"
  {% elsif flag?(:aarch64) %}
    class_getter arch = "arm64"
  {% else %}
    raise "unsupported architecure"
  {% end %}

  # All system environment variables
  private def self.get_vars
    {% begin %}
    {
      {% for var in %w(arch kernel kernel_ver sysinit sysinit_ver) %}\
        {{var}} => {{var.id}},
      {% end %}
    }
    {% end %}
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
