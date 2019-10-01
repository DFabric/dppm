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
  def self.euid : LibC::UidT
    LibC.geteuid
  end

  # Returns the real user ID of the current process.
  def self.uid : LibC::UidT
    LibC.getuid
  end

  def self.root? : Bool
    LibC.getgid == 0
  end
end

struct DPPM::Host
  class_getter kernel_ver : String = File.read("/proc/version").partition(" version ")[2].partition('-')[0]

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
    Logger.error "unsupported system"; exit 1
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
    Logger.error "Unsupported architecture"; exit 1
  {% end %}

  def self.service_available?
    Service.init? || Logger.warn "services management unavailable", "DPPM is still usable. Consider OpenRC or systemd init systems"
    Service.init?
  end

  # All system environment variables
  class_getter vars : Hash(String, String) do
    service_available?
    {
      "arch"        => @@arch,
      "kernel"      => @@kernel,
      "kernel_ver"  => @@kernel_ver,
      "sysinit"     => (Service.init.type if Service.init?).to_s,
      "sysinit_ver" => (Service.init.version if Service.init?).to_s,
    }
  end

  def self.tcp_port_available(port_num : UInt16) : UInt16?
    TCPServer.new(port_num).close
    port_num
  end

  def self.udp_port_available(port_num : UInt16) : UInt16?
    udp_ipv4_port_available(port_num) || udp_ipv6_port_available(port_num)
  end

  def self.udp_ipv4_port_available(port_num : UInt16) : UInt16?
    sock = UDPSocket.new Socket::Family::INET
    sock.bind "127.0.0.1", port_num
    sock.close
    port_num
  end

  def self.udp_ipv6_port_available(port_num : UInt16) : UInt16?
    sock = UDPSocket.new Socket::Family::INET6
    sock.bind "::1", port_num
    sock.close
    port_num
  end

  # Returns an available port
  def self.available_port(start_port : UInt16 = 0_u16) : UInt16
    ports_used = Set(UInt16).new
    (start_port..UInt16::MAX).each do |port|
      begin
        tcp_port_available port
        return port
      rescue ex : Errno
        ports_used << port
      end
    end
    raise "Limit of #{UInt16::MAX} for port numbers is reached, no ports available"
  end

  def self.exec(command : String, args : Array(String) | Tuple) : String
    Exec.new command, args, output: DPPM::Logger.output, error: DPPM::Logger.error do |process|
      raise "Execution returned an error: #{command} #{args.join ' '}" if !process.wait.success?
    end
    "success"
  end
end
