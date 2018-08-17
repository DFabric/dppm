module Service
  def cli_boot(prefix, service, state)
    system.new(service).boot Utils.to_b(state)
  end

  def cli_status(prefix, services : Array(String))
    (services.empty? ? system : services).each do |app|
      service = system.new app
      if service.exists?
        puts app
        puts "run: #{(r = service.run?) ? r.colorize.green : r.colorize.red}"
        puts "boot: #{(b = service.boot?) ? b.colorize.green : b.colorize.red}\n\n"
      else
        abort "service doesn't exist: " + app
      end
    end
  end

  def logs_cli(prefix, service, error)
    log_dir = system.new(service).log_dir
    File.read log_dir + (error ? "error.log" : "output.log")
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
end
