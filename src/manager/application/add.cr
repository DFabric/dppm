struct Manager::Application::Add
  getter app : Prefix::App,
    vars : Hash(String, String)
  @add_service : Bool
  @socket : Bool
  @shared : Bool
  @uid : UInt32
  @gid : UInt32
  @user : String
  @group : String
  @pkg : Prefix::Pkg
  @web_server_uid : UInt32? = nil
  @database : Prefix::App? = nil
  @database_password : String? = nil
  @deps : Set(Prefix::Pkg)

  def initialize(
    @pkg : Prefix::Pkg,
    @vars : Hash(String, String),
    @deps : Set(Prefix::Pkg),
    @shared : Bool = true,
    @add_service : Bool = true,
    @socket : Bool = false,
    database : String? = nil,
    url : String? = nil,
    web_server : String? = nil
  )
    Log.info "getting name", @pkg.name
    @app = @pkg.new_app @vars["name"]?

    if @add_service
      @app.service?.try do |service|
        if !service.creatable?
          Log.warn "service creation not available - root permissions missing?", service.file
          @add_service = false
        elsif service.exists?
          raise "system service already exist: " + service.name
        end
      end
    end
    @app.exists!

    @uid, @gid, @user, @group = initialize_owner

    if database
      @database = database_app = @pkg.prefix.new_app database
      Log.info "initialize database", database

      (@app.database_create database_app).tap do |database|
        database.clean
        database.check_user
        @vars.merge! database.vars
      end
    end

    # Default variables
    unset_vars = Set(String).new

    if !@socket && (port = @vars["port"]?)
      Log.info "checking port availability", port
      Host.tcp_port_available port.to_u16
    end

    source_package = @pkg.exists? || @pkg.src

    if web_server
      webserver = @app.prefix.new_app web_server
      @web_server_uid = webserver.file_info.owner
      @app.website = webserver.new_website @app.name, source_package.conf_dir
      @vars["web_server"] = web_server
    end

    set_url = false
    source_package.each_config_key do |var|
      if !@vars.has_key? var
        # Skip if a socket is used
        if var == "port" && @socket
          next
        elsif var == "database_password" && @app.database?
          @database_password = @vars["database_password"] = Database.gen_password
          next
        elsif var == "url"
          set_url = true
          next
        end

        key = source_package.get_config(var).to_s
        if key.empty?
          unset_vars << var
        else
          if var == "port"
            @vars["port"] = Host.available_port(key.to_u16).to_s
          else
            @vars[var] = key
          end
          Log.info "default value set '#{var}'", key
        end
      end
    end

    if url
      @vars["url"] = url
      @vars["domain"] = URI.parse(url).hostname.to_s
    elsif host = @vars["host"]?
      @vars["domain"] = host
      if set_url
        @vars["url"] = "http://" + @vars["host"] + '/' + @app.name
      end
    end

    # Database required
    if !@vars.has_key?("database_type") && (databases = source_package.pkg_file.databases)
      if Database.supported?(database_type = databases.first.first)
        raise "database password required: " + database_type if !@database_password
        raise "database name required: " + database_type if !@vars.has_key?("database_name")
        raise "database user required: " + database_type if !@vars.has_key?("database_user")
        if !@vars.has_key?("database_address") || !(@vars.has_key?("database_host") && @vars.has_key?("database_port"))
          raise "database address or host and port required:" + database_type
        end
      end
    end
    raise "socket not supported by #{@app.pkg_file.name}" if @socket && !@vars.has_key? "socket"
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?

    @vars["package"] = @pkg.package
    @vars["version"] = @pkg.version
    @vars["basedir"] = @app.path
    @vars["name"] = @app.name
    @vars["uid"] = @uid.to_s
    @vars["gid"] = @gid.to_s
    @vars["user"] = @user
    @vars["group"] = @group
    if env = @app.pkg_file.env
      @vars.merge! env
    end
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
    raise Exception.new "error while setting user and group:\n#{ex}", ex
  end

  def simulate(io = Log.output)
    io << "task: add"
    @vars.each do |var, value|
      io << '\n' << var << ": " << value
    end
    @app.simulate_deps @deps, io
  end

  def run
    Log.info "adding to the system", @app.name
    raise "application directory already exists: " + @app.path if File.exists? @app.path

    # Create the new application
    Dir.mkdir @app.path

    app_shared = @shared
    if !@app.pkg_file.shared
      Log.warn "can't be shared, must be self-contained", @app.pkg_file.package
      app_shared = false
    end

    if app_shared
      Log.info "creating symlinks from " + @pkg.path, @app.path
      File.symlink @pkg.app_path, @app.app_path
      File.symlink @pkg.pkg_file.path, @app.pkg_file.path
    else
      Log.info "copying from " + @pkg.path, @app.path
      FileUtils.cp_r @pkg.app_path, @app.app_path
      FileUtils.cp_r @pkg.pkg_file.path, @app.pkg_file.path
    end

    # Copy configurations and data
    Log.info "copying configurations and data", @app.name

    copy_dir @pkg.conf_dir, @app.conf_dir
    copy_dir @pkg.data_dir, @app.data_dir
    Dir.mkdir @app.logs_dir

    # Build and add missing dependencies and copy library configurations
    @app.install_deps @deps, @vars.dup, @shared do |dep_pkg|
      if dep_config = dep_pkg.config
        Log.info "copying library configuration files", dep_pkg.name
        dep_conf_dir = @app.conf_dir + dep_pkg.package
        Dir.mkdir_p dep_conf_dir
        FileUtils.cp dep_pkg.config_file!.path, dep_conf_dir + '/' + File.basename(dep_pkg.config_file!.path)
      end
    end

    @app.add(
      vars: @vars,
      uid: @uid,
      gid: @gid,
      user: @user,
      group: @group,
      add_service: @add_service,
      app_database: @database,
      database_password: @database_password,
      web_server_uid: @web_server_uid,
    )
    self
  rescue ex
    begin
      @app.delete false { }
    ensure
      raise Exception.new "add failed - application deleted: #{@app.path}:\n#{ex}", ex
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
