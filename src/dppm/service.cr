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

  def check(pkgtype, package, &log : String, String, String -> Nil)
    if HOST.service.writable?
      raise "system service already exist: " + package if system.new(package).exists?
    else
      log.call "WARN", "system service unavailable", "root execution needed"
    end
    raise "only applications can be added to the system" if pkgtype != "app"
  end

  def create(pkg, vars, &log : String, String, String -> Nil)
    log.call "INFO", "creating services", "etc/init"

    # Ensure we are on pkgdir, needed for PATH generation
    initdir = vars["pkgdir"] + "etc/init/"
    Dir.mkdir_p initdir

    # Initialize init services as hashes
    systemd = Hash
    openrc = Hash
    {% for sysinit in ["OpenRC", "Systemd"] %}
    {
      {{sysinit.downcase.id}} = if File.exists? initdir + {{sysinit.downcase}}
        {{sysinit.id}}.parse(File.read initdir + {{sysinit.downcase}})
      else
        {{sysinit.id}}.base
      end
    }
    {% end %}

    # Set service options
    {description:   pkg["description"].as_s,
     directory:     vars["pkgdir"],
     command:       vars["pkgdir"] + pkg["exec"]["start"].as_s,
     user:          vars["user"],
     group:         vars["group"],
     restart_delay: "9",
     umask:         "027"}.each do |key, value|
      openrc = OpenRC.set openrc, key.to_s, value
      systemd = Systemd.set systemd, key.to_s, value
    end

    # Reload directive if available
    if pkg["exec"]["reload"]?
      openrc = OpenRC.set openrc, "reload", pkg["exec"]["reload"].as_s
      systemd = Systemd.set systemd, "reload", pkg["exec"]["reload"].as_s
    end

    # Add a OATH environment variable
    path = Dir[vars["pkgdir"] + "lib/*/bin"].join ':'
    if !path.empty?
      openrc = OpenRC.env_set openrc, "PATH", path
      systemd = Systemd.env_set systemd, "PATH", path
    end

    # Convert back hashes to service files
    File.write vars["pkgdir"] + "etc/init/openrc", OpenRC.build openrc
    File.write vars["pkgdir"] + "etc/init/systemd", Systemd.build systemd
  end

  def link(vars, &log : String, String, String -> Nil)
    # Create links
    if HOST.service.writable?
      Service.system.new(vars["package"]).link vars["pkgdir"]
      log.call "INFO", HOST.service.name + " system service added", vars["package"]
    else
      log.call "WARN", "root execution needed for system service addition", vars["package"]
    end
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
