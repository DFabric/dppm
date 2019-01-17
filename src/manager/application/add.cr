struct Manager::Application::Add
  getter app : Prefix::App,
    vars : Hash(String, String)
  @socket : Bool
  @shared : Bool
  @uid : UInt32
  @gid : UInt32
  @user : String
  @group : String
  @build : Package::Build
  @database : Prefix::App? = nil
  @database_password : String? = nil

  def initialize(@build : Package::Build, @shared : Bool = true, add_service : Bool = true, @socket : Bool = false, database : String? = nil)
    @vars = @build.vars.dup

    Log.info "getting name", @build.pkg.name
    @app = @build.pkg.new_app @vars["name"]?

    if add_service
      @app.service?.try do |service|
        service.check_availability
      end
    end
    raise "application directory already exists: " + @app.path if File.exists? @app.path

    @uid, @gid, @user, @group = initialize_owner

    if database
      database_app = @build.pkg.prefix.new_app database
      Log.info "initialize database", database
      (@app.database = database_app).try do |database|
        database.clean
        database.check
        @vars.merge! database.vars
      end
      @database = database_app
    end

    # Default variables
    unset_vars = Set(String).new

    if !@socket && (port = @vars["port"]?)
      Log.info "checking port availability", port
      Host.tcp_port_available port.to_u16
    end

    if @build.pkg.src.pkg_file.config?
      @build.pkg.src.pkg_file.config.each_key do |var|
        if !@vars.has_key? var
          # Skip if a socket is used
          if var == "port" && @socket
            next
          elsif var == "database_password" && @app.database?
            @database_password = @vars["database_password"] = Database.gen_password
            next
          end

          key = @build.pkg.src.get_config(var).to_s
          if key.empty?
            unset_vars << var
          else
            if var == "port"
              @vars["port"] = Host.available_port(key.to_u16).to_s
            else
              @vars[var] = key
            end
            Log.info "default value set for unset variable", var + ": " + key
          end
        end
      end
    end
    raise "socket not supported by #{@app.pkg_file.name}" if @socket && !@vars.has_key? "socket"
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?

    @vars["package"] = @build.pkg.package
    @vars["version"] = @build.pkg.version
    @vars["basedir"] = @app.path
    @vars["name"] = @app.name
    @vars["uid"] = @uid.to_s
    @vars["gid"] = @gid.to_s
    @vars["user"] = @user
    @vars["group"] = @group
  end

  # An user uid and a group gid is required
  private def initialize_owner : Tuple(UInt32, UInt32, String, String)
    if Process.root?
      libcrown = Libcrown.new
      uid = gid = libcrown.available_id 9000
      if uid_string = @vars["uid"]?
        uid = uid_string.to_u32
        user = libcrown.users[uid].name
      elsif user = @vars["user"]?
        uid = libcrown.to_uid user
      else
        user = '_' + @app.name
      end
      if gid_string = @vars["gid"]?
        gid = gid_string.to_u32
        group = libcrown.groups[gid].name
      elsif group = @vars["group"]?
        gid = libcrown.to_gid group
      else
        group = '_' + @app.name
      end
    else
      libcrown = Libcrown.new nil
      uid = Process.uid
      gid = Process.gid
      user = libcrown.users[uid].name
      group = libcrown.users[gid].name
    end
    {uid, gid, user, group}
  rescue ex
    raise "error while setting user and group: #{ex}"
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      @build.simulate_deps str
    end
  end

  def run
    Log.info "adding to the system", @app.name
    raise "application directory already exists: " + @app.path if File.exists? @app.path

    # Create the new application
    Dir.mkdir @app.path
    @build.run if !@build.exists

    # Build and add missing dependencies
    Package::Deps.new(@app.prefix, @app.libs_dir).build @vars.dup, @build.deps, @shared

    app_shared = @shared
    if !@app.pkg_file.shared
      Log.warn "can't be shared, must be self-contained", @app.pkg_file.package
      app_shared = false
    end

    if app_shared
      Log.info "creating symlinks from " + @build.pkg.path, @app.path
      File.symlink @build.pkg.app_path, @app.app_path
      File.symlink @build.pkg.pkg_file.path, @app.pkg_file.path
    else
      Log.info "copying from " + @build.pkg.path, @app.path
      FileUtils.cp_r @build.pkg.app_path, @app.app_path
      FileUtils.cp_r @build.pkg.pkg_file.path, @app.pkg_file.path
    end

    # Copy configurations and data
    Log.info "copying configurations and data", @app.name

    copy_dir @build.pkg.conf_dir, @app.conf_dir
    copy_dir @build.pkg.data_dir, @app.data_dir
    Dir.mkdir @app.logs_dir
    @app.set_permissions

    # Set configuration variables
    Log.info "setting configuration variables", @app.name
    if @app.pkg_file.config?
      @app.pkg_file.config.each_key do |var|
        if var == "socket"
          next
        elsif variable_value = @vars[var]?
          @app.set_config var, variable_value
        end
      end
      @app.config.write
    end

    # PHP-FPM based application
    if (deps = @app.pkg_file.deps) && deps.has_key? "php"
      php_fpm_conf = @app.conf_dir + "php-fpm.conf"
      FileUtils.cp(@app.libs_dir + "php/etc/php-fpm.conf", php_fpm_conf) if !File.exists? php_fpm_conf
      php_fpm = Prefix::PkgFile.new @app.libs_dir + "php"
      @app.pkg_file.exec = php_fpm.exec
    end

    @app.database?.try do |database|
      Log.info "configure database", @database.not_nil!.name
      database.ensure_root_password @database.not_nil!
      database.create @database_password.not_nil!
    end

    # Running the add task
    Log.info "running configuration tasks", @build.pkg.name
    if (tasks = @app.pkg_file.tasks) && (add_task = tasks["add"]?)
      Dir.cd(@app.path) { Cmd.new(@vars.dup).run add_task }
    end

    # Create system user and group for the application
    if Process.root?
      @app.service?.try do |service|
        # Create system services
        service.create @app, @user, @group
        service.enable @app
        Log.info service.type + " system service added", service.name
      end

      libcrown = Libcrown.new
      add_group_member = false
      # Add a new group
      if !libcrown.groups.has_key? @gid
        Log.info "system group created", @group
        libcrown.add_group Libcrown::Group.new(@group), @gid
        add_group_member = true
      end

      if !libcrown.users.has_key? @uid
        # Add a new user with `new_group` as its main group
        new_user = Libcrown::User.new(
          name: @user,
          gid: @gid,
          gecos_comment: @app.pkg_file.description,
          home_directory: @app.data_dir
        )
        libcrown.add_user new_user, @uid
        Log.info "system user created", @user
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
      @app.service.try &.delete
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
