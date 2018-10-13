require "socket"

struct System::Host
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
      Log.warn "unsupported init system", "consider to migrate to OpenRC if you are still in SysVinit: " + init
    end
  end

  # System's kernel
  {% if flag?(:linux) %}
    class_getter kernel = "linux"
  {% elsif flag?(:freebsd) %}
    class_getter kernel = "freebsd"
  {% elsif flag?(:openbsd) %}
    class_getter kernel = "openbsd"
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
      "sysinit"     => _service ? _service.name : "",
      "sysinit_ver" => (_service.version if _service).to_s,
    }
  end
end
