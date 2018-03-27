struct Service::OpenRC::System
  getter service : String

  def initialize(@service)
  end

  def file
    "/etc/init.d/" + @service
  end

  def boot?
    File.exists? "/etc/runlevels/default/" + @service
  end

  def exists?
    File.exists? file
  end

  def writable?
    File.writable? file
  end

  def link(src)
    File.symlink src + "/etc/init/systemd", file
    File.chmod file, 0o750
  end

  def boot(value : Bool)
    boot = "/etc/runlevels/default/" + @service
    value ? File.symlink(file, boot) : File.delete(boot)
  end

  def run?
    Exec.new("/sbin/rc-service", [@service, "status"]).success?
  end

  def run(value : Bool) : Bool
    boot = "/etc/runlevels/default/" + @service
    Exec.new("/sbin/rc-service", [@service, (value ? "start" : "stop")]).success?
  end

  def reload
    Exec.new("/sbin/rc-service", [@service, "reload"]).success?
  end
end
