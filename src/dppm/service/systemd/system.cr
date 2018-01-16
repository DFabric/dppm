struct Service::Systemd::System
  getter service : String

  def initialize(@service)
  end

  def file
    "/etc/systemd/system/" + @service + ".service"
  end

  def boot?
    File.exists? "/etc/systemd/system/multi-user.target.wants/" + @service + ".service"
  end

  def exists?
    File.exists? file
  end

  def writable?
    File.writable? file
  end

  def link(src)
    File.symlink src + "/etc/init/systemd", file
    Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"]
  end

  def boot(value : Bool)
    boot = "/etc/systemd/system/multi-user.target.wants/" + @service + ".service"
    value ? File.symlink(file, boot) : File.delete(boot)
  end

  def run?
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "is-active", @service]).success?
  end

  def run(value : Bool) : Bool
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", (value ? "start" : "stop"), @service]).success?
  end

  def reload
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "reload", @service]).success?
  end
end
