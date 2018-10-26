module Service::System
  getter name : String,
    file : String,
    boot_file : String,
    init_path : String

  def boot? : Bool
    File.exists? @boot_file
  end

  def exists? : Bool
    File.symlink?(@file) || File.exists?(@file)
  end

  def writable? : Bool
    File.writable? @file
  end

  def boot(value : Bool) : Bool
    case value
    when boot? # nothing to do
    when true  then File.symlink @file, @boot_file
    when false then File.delete boot_file
    end
    value
  end

  def real_file : String
    File.real_path file
  end

  def check_availability(pkgtype)
    if pkgtype != "app"
      raise "only applications can be added to the system"
    elsif exists?
      raise "system service already exist: " + name
    elsif !File.writable? File.dirname(@file)
      Log.warn "service creation unavailable, root permissions required", name
    else
      Log.info "service available for creation", name
    end
  end

  def is_app?(pkgdir : String) : Bool
    real_file == pkgdir + @init_path
  end

  def check_delete
    if !writable?
      Log.error "root execution needed for system service deletion: " + name
    elsif !exists?
      Log.error "service doesn't exist: " + name
    end
  end

  def create(pkg : YAML::Any, pkgdir : String, user : String, group : String)
    sysinit_hash = config.parse pkgdir + init_path

    Dir.mkdir_p pkgdir + Service::ROOT_PATH

    Log.info "creating system service", name

    # Set service options
    {description:   pkg["description"].as_s,
     directory:     pkgdir,
     command:       "#{pkgdir}/#{pkg["exec"]["start"]}",
     user:          user,
     group:         group,
     restart_delay: "9",
     umask:         "027"}.each do |key, value|
      sysinit_hash.set key.to_s, value
    end

    # add a reload directive if available
    if exec_reload = pkg["exec"]["reload"]?
      sysinit_hash.set("reload", exec_reload.as_s)
    end

    # Add a PATH environment variable if not empty
    path = Path.env_var pkgdir
    sysinit_hash.env_set("PATH", path) if !path.empty?
    if pkg_env = pkg["env"]?
      pkg_env.as_h.each { |var, value| sysinit_hash.env_set var.to_s, value.to_s }
    end

    finalize_create pkgdir, sysinit_hash

    # Convert back hashes to service files
    File.write pkgdir + @init_path, sysinit_hash.build
  end
end
