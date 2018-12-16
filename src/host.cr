require "socket"

lib LibC
  fun getegid : GidT
  fun getgid : GidT
  fun geteuid : UidT
  fun getuid : UidT
end

class Process
  # Returns the effective group ID of the current process.
  def self.egid : LibC::GidT
    LibC.getegid
  end

  # Returns the real group ID of the current process.
  def self.gid : LibC::GidT
    LibC.getgid
  end

  # Returns the effective user ID of the current process.
  def self.euid : LibC::GidT
    LibC.geteuid
  end

  # Returns the real user ID of the current process.
  def self.uid : LibC::GidT
    LibC.getuid
  end

  def self.root? : Bool
    LibC.getgid == 0
  end
end

struct Host
  class_getter proc_ver : Array(String) = File.read("/proc/version").split(' '),
    kernel_ver : String = proc_ver[2].split('-')[0]

  @@service : Service::Systemd.class | Service::OpenRC.class | Nil = get_sysinit

  def self.service?
    @@service
  end

  def self.service
    if _service = @@service
      _service
    else
      raise "unsupported init system"
    end
  end

  private def self.get_sysinit
    init = File.basename File.real_path "/sbin/init"
    if init == "systemd"
      Service::Systemd
    elsif File.exists? "/sbin/openrc"
      Service::OpenRC
    else
      Log.warn "services management unavailable", "DPPM is still usable. Consider OpenRC or systemd init systems instead of `" + init + '`'
    end
  end

  # System's kernel
  {% if flag?(:linux) %}
    class_getter kernel = "linux"
  {% elsif flag?(:freebsd) %}
    class_getter kernel = "freebsd"
  {% elsif flag?(:openbsd) %}
    class_getter kernel = "openbsd"
  {% elsif flag?(:darwin) %}
    class_getter kernel = "darwin"
  {% else %}
    Log.error "unsupported system"
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
    Log.error "unsupported architecure"
  {% end %}

  # All system environment variables
  def self.vars : Hash(String, String)
    _service = @@service
    {
      "arch"        => @@arch,
      "kernel"      => @@kernel,
      "kernel_ver"  => @@kernel_ver.to_s,
      "sysinit"     => _service ? _service.type : "",
      "sysinit_ver" => (_service.version if _service).to_s,
    }
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
