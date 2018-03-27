module Service
  extend self

  def init(sysinit = HOST.sysinit)
    case sysinit
    when "systemd" then Systemd
    when "openrc"  then OpenRC
    else
      raise "unsupported init system"
    end
  end

  def system(sysinit = HOST.sysinit)
    case sysinit
    when "systemd" then Systemd::System
    when "openrc"  then OpenRC::System
    else
      raise "unsupported init system"
    end
  end

  def check_availability(pkgtype, package, &log : String, String, String -> Nil)
    if pkgtype != "app"
      raise "only applications can be added to the system"
    elsif system.new(package).exists?
      raise "system service already exist: " + package
    elsif !HOST.service.writable?
      log.call "WARN", "system service unavailable", "root execution needed"
    end
  end

  private macro creation(sysinit, pkg, vars, &log : String, String, String -> Nil)
    log.call "INFO", "creating services for #{{{sysinit}}}", "etc/init/" + {{sysinit.downcase}}

    # Ensure we are on pkgdir, needed for PATH generation
    initdir = vars["pkgdir"] + "etc/init/"
    Dir.mkdir_p initdir

    if File.exists? initdir + {{sysinit.downcase}}
      sysinit_hash = {{sysinit.id}}::Config.new initdir + {{sysinit.downcase}}, file: true
    else
      sysinit_hash = {{sysinit.id}}::Config.new
    end

    # Set service options
    {description:   pkg["description"].as_s,
     directory:     vars["pkgdir"],
     command:       vars["pkgdir"] + pkg["exec"]["start"].as_s,
     user:          vars["user"],
     group:         vars["group"],
     restart_delay: "9",
     umask:         "027"}.each do |key, value|
      sysinit_hash.set key.to_s, value
    end

    # add a reload directive if available
    sysinit_hash.set("reload", pkg["exec"]["reload"].as_s) if pkg["exec"]["reload"]?

    # Add a PATH environment variable if not empty
    path = Dir[vars["pkgdir"] + "lib/*/bin"].join ':'
    sysinit_hash.env_set("PATH", path) if !path.empty?

    sysinit_hash
  end

  def delete(service, &log : String, String, String -> Nil)
    log.call "INFO", "deleting the system service", service
    if HOST.service.writable?
      service = Service.system.new(service)
      service.run false if service.run?
      service.boot false if service.boot?

      File.delete service.file
      Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"] if HOST.service.name == "systemd"
    else
      log.call "WARN", "root execution needed for system service deletion", service
    end
  end
end
