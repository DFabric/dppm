module Service
  macro change_state
  def action(type)
    case type
    {% for action in %w(start stop restart reload) %}
    when {{action}} then {{action.id}}
    {% end %}
    else
      raise "unknown action: " + type
    end
  end
  end

  def self.cli(services : Array(String), action, boot)
    (services.empty? ? Localhost.service.system : services).each do |app|
      service = Localhost.service.system.new app
      print app
      if service.exists?
        service.action(action) if action
        puts "\nrun: #{(r = service.run?) ? r.colorize.green : r.colorize.red}"
        if boot_str = boot
          service.boot(Utils.to_b boot_str)
        end
        puts "boot: #{(b = service.boot?) ? b.colorize.green : b.colorize.red}\n\n"
      else
        puts " doesn't exist"
      end
    end
  end

  def check_availability(pkgtype, package)
    if pkgtype != "app"
      raise "only applications can be added to the system"
    elsif system.new(package).exists?
      raise "system service already exist: " + package
    elsif !writable?
      Log.warn "system service unavailable", "root execution needed"
    end
  end

  def creation(sysinit_hash, pkg, vars)
    Dir.mkdir_p vars["pkgdir"] + "/etc/init"

    Log.info "creating services for #{name}", "etc/init/" + name

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

  def delete(service)
    Log.info "deleting the system service", service
    if writable?
      service = system.new service
      service.stop
      service.boot false if service.boot?

      File.delete service.file
      Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"] if Localhost.service.name == "systemd"
    else
      Log.info "root execution needed for system service deletion", service
    end
  end
end
