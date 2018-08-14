struct Service::OpenRC::System < Service::System
  getter service : String
  getter file : String
  getter boot : String
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

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Exec.new("/sbin/rc-service", [@service, {{action}}]).success?
  end
  {% end %}
end
