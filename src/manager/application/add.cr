struct Manager::Application::Add
  getter package : String,
    name : String,
    app : Prefix::App,
    version : String,
    vars : Hash(String, String)
  @deps = Hash(String, String).new
  @socket : Bool
  @shared : Bool
  @uid : UInt32
  @gid : UInt32
  @service : Service::Systemd | Service::OpenRC | Nil
  @build : Package::Build

  def initialize(@vars, prefix : Prefix, @shared : Bool = true, add_service : Bool = true, @socket : Bool = false)
    # Build missing dependencies
    @build = Package::Build.new vars.dup, prefix
    @version = @vars["version"] = @build.version
    @package = @vars["package"] = @build.package
    @deps = @build.deps

    Log.info "getting name", @package
    getname
    @name = @vars["name"]
    @app = @build.pkg.new_app @name

    if add_service && (service = Host.service?.try &.new @name)
      service.check_availability @app.pkg_file.type
      @service = service
    end
    @vars["basedir"] = @app.path
    raise "application directory already exists: " + @app.path if File.exists? @app.path

    # Check database type
    Log.info "calculing informations", @app.path
    if (db_type = @vars["database_type"]?) && (databases = @app.pkg_file.databases)
      raise "unsupported database type: " + db_type if !databases[db_type]?
    end

    # Default variables
    unset_vars = Array(String).new
    if pkg_config = @build.src.pkg_file.config
      pkg_config.each_key do |var|
        # Skip if a socket is used
        next if var == "port" && @socket
        if !@vars[var]?
          key = @build.src.get_config(var).to_s
          if key.empty?
            unset_vars << var
          else
            @vars[var] = key
            Log.info "default value set for unset variable", var + ": " + key
          end
        end
      end
    end
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?

    @uid, @gid = initialize_uid_gid
    @vars["uid"] = @uid.to_s
    @vars["gid"] = @gid.to_s
    raise "socket not supported by #{@app.pkg_file.name}" if @socket

    if !@socket && (port_string = @vars["port"]?)
      @vars["port"] = Host.available_port(port_string.to_i).to_s
    end
  end

  # An user uid and a group gid is required
  private def initialize_uid_gid : Tuple(UInt32, UInt32)
    if Process.root?
      libcrown = Libcrown.new
      uid = gid = libcrown.available_id 9000
      if uid_tring = @vars["uid"]?
        uid = uid_tring.to_u32
        @vars["user"] = libcrown.users[uid].name
      elsif user = @vars["user"]?
        uid = libcrown.to_uid user
      else
        @vars["user"] = '_' + @name
      end
      if gid_string = @vars["gid"]?
        gid = gid_string.to_u32
        @vars["user"] = libcrown.groups[gid].name
      elsif group = @vars["group"]?
        gid = libcrown.to_gid group
      else
        @vars["group"] = '_' + @name
      end
    else
      libcrown = Libcrown.new nil
      uid = Process.uid
      gid = Process.gid
      @vars["user"] = libcrown.users[uid].name
      @vars["group"] = libcrown.users[gid].name
    end
    {uid, gid}
  rescue ex
    raise "error while setting user and group: #{ex}"
  end

  private def getname
    # lib and others
    case @build.pkg.pkg_file.type
    when "lib"
      raise "only applications can be added to the system"
    when "app"
      @vars["name"] ||= Utils.gen_name @package
      Utils.ascii_alphanumeric_dash? @vars["name"]
    else
      raise "unknow type: #{@build.pkg.pkg_file.type}"
    end
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      str << "\ndeps: " << @deps.map { |k, v| k + ':' + v }.join(", ") if !@deps.empty?
    end
  end

  def run
    Log.info "adding to the system", @name
    raise "application directory already exists: " + @app.path if File.exists? @app.path

    # Create the new application
    Dir.mkdir @app.path
    @build.run if !@build.exists

    # Build and add missing dependencies
    Package::Deps.new(@app.prefix, @app.lib).build @vars.dup, @deps, @shared

    app_shared = @shared
    if !@app.pkg_file.shared
      Log.warn "can't be shared, must be self-contained", @app.pkg_file.package
      app_shared = false
    end

    if app_shared
      Log.info "creating symlinks from " + @build.pkg.path, @app.path
      File.symlink @build.pkg.app_dir, @app.app_dir
      File.symlink @build.pkg.pkg_file.path, @app.pkg_file.path
    else
      Log.info "copying from " + @build.pkg.path, @app.path
      FileUtils.cp_r @build.pkg.app_dir, @app.app_dir
      FileUtils.cp_r @build.pkg.pkg_file.path, @app.pkg_file.path
    end

    # Copy configurations and data
    Log.info "copying configurations and data", @name

    copy_dir @build.pkg.conf, @app.conf
    copy_dir @build.pkg.data, @app.data
    Dir.mkdir @app.log_dir
    @app.set_permissions

    # Set configuration variables
    Log.info "setting configuration variables", @name
    if pkg_config = @app.pkg_file.config
      pkg_config.each_key do |var|
        if var == "socket"
          next
        elsif variable_value = @vars[var]?
          @app.set_config var, variable_value
        end
      end
    end

    # PHP-FPM based application
    if (deps = @app.pkg_file.deps) && deps.has_key? "php"
      php_fpm_conf = @app.conf + "/php-fpm.conf"
      FileUtils.cp(@app.lib + "/php/etc/php-fpm.conf", php_fpm_conf) if !File.exists? php_fpm_conf
      php_fpm = Prefix::PkgFile.new @app.lib + "/php"
      @app.pkg_file.exec = php_fpm.exec
    end

    # Running the add task
    Log.info "running configuration tasks", @package
    if (tasks = @app.pkg_file.tasks) && (add_task = tasks["add"]?)
      Dir.cd(@app.path) { Cmd.new(@vars.dup).run add_task.as_a }
    end

    @service.try do |service|
      # Create system services
      service.create @app, @vars["user"], @vars["group"]
      service.enable @app.path
      Log.info service.class.type + " system service added", service.name
    end

    # Create system user and group for the application
    if Process.root?
      libcrown = Libcrown.new
      add_group_member = false
      # Add a new group
      if !libcrown.groups.has_key? @gid
        Log.info "system group created", @vars["group"]
        libcrown.add_group Libcrown::Group.new(@vars["group"]), @gid
        add_group_member = true
      end

      if !libcrown.users.has_key? @uid
        # Add a new user with `new_group` as its main group
        new_user = Libcrown::User.new(
          name: @vars["user"],
          gid: @gid,
          gecos_comment: @app.pkg_file.description,
          home_directory: @app.data
        )
        libcrown.add_user new_user, @uid
        Log.info "system user created", @vars["user"]
      else
        !libcrown.user_group_member? @uid, @gid
        add_group_member = true
      end
      libcrown.add_group_member(@uid, @gid) if add_group_member

      # Save the modifications to the disk
      libcrown.write
      Utils.chown_r @app.path, @uid, @gid
    end

    Log.info "add completed", @app.path
    Log.info "application information", @app.pkg_file.info
    self
  rescue ex
    FileUtils.rm_rf @app.path
    begin
      @service.try &.delete
    ensure
      raise "add failed - application deleted: #{@app.path}:\n#{ex}"
    end
  end

  private def copy_dir(src : String, dest : String)
    if !File.exists? dest
      if File.exists? src
        FileUtils.cp_r src, dest
      else
        Dir.mkdir dest
      end
    end
  end
end
