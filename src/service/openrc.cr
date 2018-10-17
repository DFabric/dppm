require "./system"

struct Service::OpenRC
  include System
  class_getter type : String = "openrc"

  def initialize(@name : String)
    @file = "/etc/init.d/" + @name
    @boot_file = "/etc/runlevels/default/" + @name
    @init_path = Service::ROOT_PATH + @@type.downcase
  end

  def config
    Config
  end

  private def finalize_create(pkgdir : String, sysinit_hash)
    # Nothing to do
  end

  def self.each
    Dir.new("/etc/init.d").each do |service|
      yield service
    end
  end

  def run?
    Exec.new("/sbin/rc-service", [@name, "status"]).success?
  end

  def delete
    stop
    boot false if boot?
    File.delete @file
  end

  def enable(pkgdir)
    File.symlink pkgdir + @init_path, @file
    File.chmod @file, 0o750
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Exec.new("/sbin/rc-service", [@name, {{action}}]).success?
  end
  {% end %}

  def self.version : String
    Exec.new("/sbin/openrc", ["-V"]).out =~ /([0-9]+\.[0-9]+\.[0-9]+)/
    $1
  rescue ex
    raise "can't retrieve the OpenRC version #{ex}"
  end
end

require "./openrc/*"
