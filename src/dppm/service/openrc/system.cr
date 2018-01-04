module Service::OpenRC
  def self.writable?
    File.writable? "/etc/init.d/"
  end

  def file(service)
    "/etc/init.d/" + service
  end

  def link(pkgdir, service)
    File.symlink pkgdir + "/etc/init/systemd", file(service)
    File.chmod file(service), 0o750
  end

  def boot(service)
    File.exists?("/etc/runlevels/default/" + service)
  end

  def boot(service, value : Bool)
    boot = "/etc/runlevels/default/" + service
    value ? File.symlink(file(service), boot) : File.delete(boot)
  end

  def run(service)
    Exec.new("/sbin/rc-service", [service, "status"]).success?
  end

  def run(service, value : Bool) : Bool
    boot = "/etc/runlevels/default/" + service
    Exec.new("/sbin/rc-service", [service, (value ? "start" : "stop")]).success?
  end

  def reload(service)
    Exec.new("/sbin/rc-service", [service, "reload"]).success?
  end
end
