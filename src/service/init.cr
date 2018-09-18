module Service::Init
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
