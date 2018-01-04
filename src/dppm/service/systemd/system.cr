module Service::Systemd
  def writable?
    File.writable? "/etc/systemd/system/"
  end

  def file(service)
    "/etc/systemd/system/" + service + ".service"
  end

  def link(pkgdir, service)
    File.symlink pkgdir + "/etc/init/systemd", file(service)
    Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"]
  end

  def boot(service)
    File.exists?("/etc/systemd/system/multi-user.target.wants/" + service + ".service")
  end

  def boot(service, value : Bool)
    boot = "/etc/systemd/system/multi-user.target.wants/" + service + ".service"
    value ? File.symlink(file(service), boot) : File.delete(boot)
  end

  def run(service)
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "is-active", service]).success?
  end

  def run(service, value : Bool) : Bool
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", (value ? "start" : "stop"), service]).success?
  end

  def reload(service)
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "reload", service]).success?
  end
end
