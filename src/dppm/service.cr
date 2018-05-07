module Service
  def check_availability(pkgtype, package, &log : String, String, String -> Nil)
    if pkgtype != "app"
      raise "only applications can be added to the system"
    elsif system.new(package).exists?
      raise "system service already exist: " + package
    elsif !writable?
      log.call "WARN", "system service unavailable", "root execution needed"
    end
  end

  def creation(sysinit_hash, pkg, vars, &log : String, String, String -> Nil)
    Dir.mkdir_p vars["pkgdir"] + "/etc/init"

    log.call "INFO", "creating services for #{name}", "etc/init/" + name

    # Set service options
    {description:   pkg["description"].as_s,
     directory:     vars["pkgdir"],
     command:       "#{vars["pkgdir"]}/#{pkg["exec"]["start"]}",
     user:          vars["user"],
     group:         vars["group"],
     restart_delay: "9",
     umask:         "027"}.each do |key, value|
      sysinit_hash.set key.to_s, value
    end

    # add a reload directive if available
    if exec_reload = pkg["exec"]["reload"]?
      sysinit_hash.set("reload", exec_reload.as_s)
    end

    # Add a PATH environment variable if not empty
    path = Dir[vars["pkgdir"] + "/lib/*/bin"].join ':'
    sysinit_hash.env_set("PATH", path) if !path.empty?
    if pkg_env = pkg["env"]?
      pkg_env.as_h.each { |var, value| sysinit_hash.env_set var.to_s, value.to_s }
    end

    sysinit_hash
  end

  def delete(service, &log : String, String, String -> Nil)
    log.call "INFO", "deleting the system service", service
    if writable?
      service = system.new(service)
      service.run false if service.run?
      service.boot false if service.boot?

      File.delete service.file
      Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"] if Localhost.service.name == "systemd"
    else
      log.call "WARN", "root execution needed for system service deletion", service
    end
  end
end
