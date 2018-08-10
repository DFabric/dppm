struct Service::OpenRC::System
  getter service : String
  getter file : String
  @boot : String
  @init_path = "/etc/init/openrc"

  def initialize(@service)
    @file = "/etc/init.d/" + @service
    @boot = "/etc/runlevels/default/" + @service
  end

  def self.each
    Dir.new("/etc/init.d").each do |service|
      yield service
    end
  end

  def boot?
    File.exists? @boot
  end

  def exists?
    File.exists? @file
  end

  def writable?
    File.writable? @file
  end

  def run?
    Exec.new("/sbin/rc-service", [@service, "status"]).success?
  end

  def delete
    stop
    boot false if boot?
    File.delete @file
  end

  def link(src)
    File.symlink src + @init_path, @file
    File.chmod @file, 0o750
  end

  def boot(value : Bool)
    # nothing to do
    return value if value == boot?

    value ? File.symlink(@file, @boot) : File.delete(@boot)
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Exec.new("/sbin/rc-service", [@service, {{action}}]).success?
  end
  {% end %}
end
