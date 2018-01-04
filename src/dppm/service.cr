module Service
  def self.create(pkg, vars, &log : String, String, String -> Nil)
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
        Service::{{sysinit.id}}.parse initdir + {{sysinit.downcase}}
      else
        Service::{{sysinit.id}}.base
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
      openrc = Service::OpenRC.set openrc, key.to_s, value
      systemd = Service::Systemd.set systemd, key.to_s, value
    end

    # Reload directive if available
    if pkg["exec"]["reload"]?
      openrc = Service::OpenRC.set openrc, "reload", pkg["exec"]["reload"].as_s
      systemd = Service::Systemd.set systemd, "reload", pkg["exec"]["reload"].as_s
    end

    # Add a OATH environment variable
    path = Dir[vars["pkgdir"] + "lib/*/bin"].join ':'
    if !path.empty?
      openrc = Service::OpenRC.set openrc, ["environment", "PATH"], path
      systemd = Service::Systemd.set systemd, ["environment", "PATH"], path
    end

    # Convert back hashes to service files
    File.write vars["pkgdir"] + "etc/init/openrc", Service::OpenRC.build openrc
    File.write vars["pkgdir"] + "etc/init/systemd", Service::Systemd.build systemd

    # Create links
    if HOST.service.writable?
      HOST.service.link vars["pkgdir"], vars["package"]
      log.call "INFO", HOST.service.name + " system service added", vars["package"]
    else
      log.call "WARN", "root execution needed for system service addition", vars["package"]
    end
  end

  def self.delete(service, &log : String, String, String -> Nil)
    log.call "INFO", "deleting the system service", service
    if HOST.service.writable?
      HOST.service.run service, false
      HOST.service.boot(service, false) if HOST.service.boot service

      File.delete HOST.service.file(service)
      Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"] if HOST.service.name == "systemd"
    else
      log.call "WARN", "root execution needed for system service deletion", service
    end
  end
end
