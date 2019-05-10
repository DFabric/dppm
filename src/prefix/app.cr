require "./program_data"
require "libcrown"
require "tail"

struct Prefix::App
  include ProgramData

  getter logs_path : Path { path / "logs" }
  getter log_file_output : Path { logs_path / "output.log" }
  getter log_file_error : Path { logs_path / "output.log" }
  getter web_site_file : Path { conf_path / "web-site" }

  protected def initialize(@prefix : Prefix, @name : String, pkg : Pkg? = nil)
    Utils.ascii_alphanumeric_dash? name
    @path = @prefix.app / @name
    if pkg
      @pkg = pkg
      pkg_pkg_file = pkg.pkg_file
      pkg_pkg_file.path = nil
      pkg_pkg_file.root_path = @path
      @pkg_file = pkg_pkg_file
    end
  end

  # Password content, typically used for the database user.
  getter password : String? do
    if File.exists? password_file
      File.read password_file
    end
  end

  # Password path, typically used for the database user.
  getter password_file : Path do
    conf_path / ".password"
  end

  getter pkg : Pkg do
    Pkg.new @prefix, File.basename(File.dirname(File.real_path(app_path.to_s))), nil, @pkg_file
  end

  getter exec : Hash(String, String) do
    if !(exec = pkg_file.exec)
      libs.each do |library|
        exec ||= library.pkg_file.exec
      end
    end
    exec || raise "exec key not present in #{pkg_file.path}"
  end

  @service_intialized = false

  # Returns the system service, if available.
  def service? : Service::OpenRC | Service::Systemd | Nil
    if !@service_intialized
      if service = Service.init?
        @service = service.new @name
      end
      @service_intialized = true
    end
    @service
  end

  # Returns the system service of the application. Raise if not present.
  getter service : Service::OpenRC | Service::Systemd do
    service? || raise "service not available"
  end

  # Service directory.
  getter service_path : Path do
    conf_path / "init"
  end

  # Service file location.
  getter service_file : Path do
    service_path / service.type
  end

  # Used to tap inside the service, to modify its reference instead of a copy.
  def service_tap(&block : Service::OpenRC | Service::Systemd -> Service::OpenRC | Service::Systemd)
    @service = yield service
  end

  # Creates a new system service
  def service_create(database_name : String? = nil)
    Dir.mkdir_p service_path.to_s

    # Set service options
    service_tap do |service|
      service.config_tap do |config|
        config.user = owner.user.name
        config.group = owner.group.name
        config.directory = @path.to_s
        config.description = pkg_file.description
        config.log_output = log_file_output.to_s
        config.log_error = log_file_error.to_s
        config.command = (path / exec["start"]).to_s
        config.after << database_name if database_name

        # add a reload directive if available
        if exec_reload = exec["reload"]?
          config.reload_signal = exec_reload
        end

        # Add a PATH environment variable if not empty
        if !(path_var = path_env_var).empty?
          config.env_vars["PATH"] = path_var
        end
        if pkg_env = pkg_file.env
          config.env_vars.merge! pkg_env
        end

        # Convert back hashes to service files
        config
      end
      File.write service_file, service.config_build
      service
    end
  end

  # Enable system service by creating a symlink.
  def service_enable
    service.link service_file.to_s
  end

  # Returns a database if already initialized.
  def database? : Database::MySQL | Nil
    @database
  end

  # Returns a database, if any.
  getter database : Database::MySQL | Nil do
    if config_vars = pkg_file.config_vars
      if database_type = get_config?("database_type")
        type = database_type.to_s
      elsif databases = pkg_file.databases
        type = databases.first.first
      else
        return
      end
      return if !Database.supported? type

      if database_address = get_config?("database_address")
        uri = URI.parse "//#{database_address}"
      elsif database_host = get_config?("database_host")
        uri = URI.new(
          host: database_host.to_s,
          port: get_config("database_port").to_s.to_i?,
        )
      end
    else
      return
    end

    if uri
      uri.password = get_config("database_password").to_s
      uri.user = user = get_config("database_user").to_s

      Database.new uri, user, type
    end
  end

  # Creates a new database for this application.
  def database_create(database_app : App) : Database::MySQL
    user = '_' + @name
    host = database_app.get_config("host").to_s
    port = database_app.get_config("port").to_s

    uri = URI.new(
      host: host,
      port: port.to_i,
      user: "root",
      password: database_app.password,
    )
    db_type = database_app.pkg_file.provides || raise "no `provides` key set, that includes the database type"
    @database = Database.new uri, user, db_type
  end

  private def config_from_libs(key : String, &block)
    libs.each do |library|
      if library_pkg_config_vars = library.pkg_file.config_vars
        if config_key = library_pkg_config_vars[key]?
          library.app_config.try do |lib_config|
            yield lib_config, config_key
          end
        end
      end
    end
  end

  private def keys_from_libs(&block : String ->)
    libs.each do |library|
      library.pkg_file.config_vars.try &.each_key do |key|
        yield key
      end
    end
  end

  def get_config(key : String)
    get_config(key) { raise "config key not found: " + key }
  end

  def get_config?(key : String)
    get_config(key) { nil }
  end

  # Get the config key. If not found, returns the block.
  def get_config(key : String, &block)
    config_from_pkg_file key do |app_config, config_key|
      config_export
      return app_config.get config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.get config_key
    end
    yield
  end

  def del_config(key : String)
    config_from_pkg_file key do |app_config, config_key|
      config_export
      return app_config.del config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.del config_key
    end
    raise "config key not found: " + key
  end

  def set_config(key : String, value)
    config_from_pkg_file key do |app_config, config_key|
      config_export
      return app_config.set config_key, value
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.set config_key, value
    end
    raise "config key not found: " + key
  end

  def each_config_key(&block : String ->)
    config_export
    internal_each_config_key do |key|
      yield key
    end
    keys_from_libs do |key|
      yield key
    end
  end

  # Write all configurations
  def write_configs
    if app_config = @config
      File.write config_file!.path, app_config.build
    end
    config_import
    libs.each do |library|
      if (lib_config_file = library.app_config_file) && (lib_config = library.app_config)
        File.write lib_config_file, lib_config.build
      end
    end
  end

  # Import the readable configuration to the application
  private def config_import
    if full_command = pkg_file.config_import
      update_configuration do
        splitted_command = full_command.split ' '
        command = splitted_command[0]
        args = splitted_command[1..-1]

        Exec.new command, args, output: Log.output, error: Log.error, chdir: @path.to_s, env: pkg_file.env do |process|
          raise "can't import configuration: " + full_command if !process.wait.success?
        end
      end
    end
  end

  # Export the application's internal configuration to a readable config file
  private def config_export
    if export = pkg_file.config_export
      update_configuration do
        full_command = export
        splitted_command = full_command.split ' '
        command = splitted_command[0]
        args = splitted_command[1..-1]

        File.open config_file!.path.to_s, "w" do |io|
          Exec.new command, args, output: io, error: Log.error, chdir: @path.to_s, env: pkg_file.env do |process|
            raise "can't export configuration: " + full_command if !process.wait.success?
          end
        end
        config_file!.rewind
        @config = ::Config.new config_file!
      end
    end
  end

  private def update_configuration(&block)
    if origin_file = pkg_file.config_origin
      origin_file = (@path / origin_file).to_s
      return if !File.exists? origin_file.to_s
      config_time = File.info(config_file!.path.to_s).modification_time
      origin_file_info = File.info origin_file
      return if config_time == origin_file_info.modification_time

      # Required by Nextcloud
      File.chown origin_file, Process.uid, Process.gid

      yield

      File.chown origin_file, origin_file_info.owner, origin_file_info.group
      time = Time.utc_now
      File.touch origin_file, time
      File.touch config_file!.path, time
    end
  end

  # Real package path of the application.
  def real_app_path : Path
    Path[File.dirname(File.real_path(app_path.to_s))]
  end

  # Use a shared application package.
  def shared? : Bool
    raise "application directory doesn't exist: " + app_path.to_s if !File.exists? app_path.to_s
    File.symlink? app_path.to_s
  end

  def each_log_file(&block : String ->)
    Dir.each_child logs_path.to_s, &block
  end

  # Get application logs
  def get_logs(file_name : String, follow : Bool = true, lines : Int32? = nil, &block : String ->)
    log_file = (logs_path / file_name).to_s
    if follow
      Tail::File.new(log_file).follow(lines: (lines || 10), &block)
    elsif lines
      yield Tail::File.new(log_file).last_lines(lines: lines.to_i).join '\n'
    else
      yield File.read log_file
    end
  end

  # Set directory access permissions
  def set_permissions
    File.chmod(libs_path.to_s, 0o700) if Dir.exists? libs_path.to_s
    File.chmod(app_path.to_s, 0o750) if !File.symlink? app_path.to_s
    File.chmod conf_path.to_s, 0o710
    File.chmod @path.to_s, 0o750
    File.chmod logs_path.to_s, 0o700
    File.chmod data_path.to_s, 0o750
  end

  def path_env_var : String
    String.build do |str|
      str << app_bin_path
      libs.each do |library|
        str << ':' << library.bin_path
      end
    end
  end

  def webserver? : Prefix::App?
    if File.exists? web_site_file
      @prefix.new_app Path[File.real_path(web_site_file.to_s)].parent.parent.basename
    end
  end

  getter? website : WebSite::Caddy? do
    if server = webserver?
      server.parse_site @name
    end
  end

  def website=(@website : WebSite::Caddy)
  end

  # Adds a new site.
  # Assumes the app is a Web Server.
  def new_website(app_name : String, build_conf_path : Path) : WebSite::Caddy
    raise "Web server doesn't exists: #{@path}" if !Dir.exists? @path
    default_site_file = build_conf_path / "web" / pkg_file.package
    site = parse_site app_name, default_site_file

    # Add security headers
    if !File.exists? default_site_file.to_s
      site.headers["Strict-Transport-Security"] = "max-age=31536000;"
      site.headers["X-XSS-Protection"] = "1; mode=block"
      site.headers["X-Content-Type-Options"] = "nosniff"
      site.headers["X-Frame-Options"] = "DENY"
      site.headers["Content-Security-Policy"] = "frame-ancestors 'none';"
    end
    site.log_file_error = logs_path / (app_name + "-error.log")
    site.log_file_output = logs_path / (app_name + "-output.log")
    site.file = conf_path / "sites" / app_name
    site
  end

  protected def parse_site(app_name : String, file : Path? = nil) : WebSite::Caddy
    file ||= conf_path / "sites" / app_name
    case pkg_file.package
    when "caddy" then WebSite::Caddy.new file
    else              raise "unsupported web server: " + pkg_file.package
    end
  end

  def upgrade(
    tag : String? = nil,
    version : String? = nil,
    vars : Hash(String, String) = Hash(String, String).new,
    shared : Bool = true,
    confirmation : Bool = true,
    &block
  )
    new_pkg = Pkg.create prefix: @prefix, name: pkg.package, version: version, tag: tag

    case new_pkg.semantic_version
    when .< pkg.semantic_version
      Log.warn "downgrading is not recommended", "from `#{pkg.version}` to `#{new_pkg.version}`"
    when .== pkg.semantic_version
      current_shared_state = shared?
      if current_shared_state == shared
        Log.info "nothing to do", pkg.version
        return self
      else
        Log.info "changing application's package shared state", "from `#{current_shared_state}` to `#{shared}`"
      end
    end

    vars["package"] = pkg.package
    vars["version_current"] = pkg.version
    vars["version"] = new_pkg.version
    vars["basedir"] = @path.to_s
    vars["name"] = @name

    if env = pkg_file.env
      vars.merge! env
    end

    deps = Set(Prefix::Pkg).new
    new_pkg.build deps, false do
      simulate vars, deps, "upgrade", confirmation, Log.output, &block
    end

    # Replace current application's package by the new one
    FileUtils.rm_r app_path.to_s
    File.delete pkg_file.path.to_s
    @pkg = new_pkg
    create_application_dir shared
    write_configs
    set_permissions

    if Process.root?
      Utils.chown_r @path.to_s, file_info.owner, file_info.group
    end

    Log.info "upgrade completed", @path.to_s
    self
  end

  def add(
    vars : Hash(String, String) = Hash(String, String).new,
    shared : Bool = true,
    add_service : Bool = true,
    socket : Bool = false,
    database : String? = nil,
    url : String? = nil,
    web_server : String? = nil,
    confirmation : Bool = true,
    &block
  )
    if add_service
      if pkg_file.type.html?
        add_service = false
      elsif app_service = service?
        if !app_service.creatable?
          Log.warn "service creation not available - root permissions missing?", app_service.file
          add_service = false
        elsif app_service.exists?
          raise "system service already exist: " + app_service.name
        end
      end
    end
    exists!

    database_app = nil
    if database
      database_app = @prefix.new_app database
      Log.info "initialize database", database

      (database_create database_app).tap do |database|
        database.clean
        database.check_user
        vars.merge! database.vars
      end
    end

    # Default variables
    unset_vars = Set(String).new

    if !socket && (port = vars["port"]?)
      Log.info "checking port availability", port
      if pkg_file.type.udp? || pkg_file.type.tcp_udp?
        Host.udp_port_available port.to_u16
      end

      if !pkg_file.type.udp?
        Host.tcp_port_available port.to_u16
      end
    end

    source_package = pkg.exists? || pkg.src
    if web_server
      if !pkg_file.type.use_url?
        raise "only HTML, HTTP and PHP applications can be serverd behind a web server: #{pkg_file.type}"
      end
      webserver = @prefix.new_app web_server
      web_server_uid = webserver.file_info.owner
      @website = webserver.new_website @name, source_package.conf_path
      vars["web_server"] = web_server
    end

    if url && pkg_file.type.use_url?
      vars["url"] = url
      vars["domain"] = URI.parse(url).hostname.to_s
    end

    set_url = false
    has_socket = false
    database_password = nil
    source_package.each_config_key do |var|
      # Skip if the var is set, or port if a socket is used
      if var == "socket"
        if !vars.has_key? "socket"
          vars["socket"] = (@path / "socket").to_s
        end
        has_socket = true
      elsif !vars.has_key?(var) && !(var == "port" && socket)
        if var == "database_password" && database?
          database_password = vars["database_password"] = Database.gen_password
        elsif var == "url"
          set_url = true
        else
          key = source_package.get_config(var).to_s
          if key.empty?
            unset_vars << var
          else
            if var == "port"
              vars["port"] = Host.available_port(key.to_u16).to_s
            else
              vars[var] = key
            end
            Log.info "default value set '#{var}'", key
          end
        end
      end
    end
    raise "socket not supported by #{pkg_file.name}" if socket && !has_socket

    if url
      vars["url"] = url
      vars["domain"] = URI.parse(url).hostname.to_s
      # A web server needs an url
    elsif set_url || web_server
      if !(domain = vars["domain"]?)
        domain = vars["host"]?
      end
      domain ||= "[::1]"
      # Add the application name as a path by default if behind a webserver
      vars["url"] = "http://" + domain + (web_server ? '/' + @name : '/')
      vars["domain"] = domain
    end

    # Database required
    if !vars.has_key?("database_type") && (databases = source_package.pkg_file.databases)
      if Database.supported?(database_type = databases.first.first)
        raise "database password required: " + database_type if !database_password
        raise "database name required: " + database_type if !vars.has_key?("database_name")
        raise "database user required: " + database_type if !vars.has_key?("database_user")
        if !vars.has_key?("database_address") || !(vars.has_key?("database_host") && vars.has_key?("database_port"))
          raise "database address or host and port required:" + database_type
        end
      end
    end
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?

    Log.info "setting system user and group", @name
    # Take an user uid and a group gid is required
    if Process.root?
      libcrown = Libcrown.new
      uid = gid = libcrown.available_id 9000
      if uid_string = vars["uid"]?
        uid = uid_string.to_u32
        user = libcrown.users[uid].name
      elsif user = vars["system_user"]?
        uid = libcrown.to_uid user
      else
        user = '_' + @name
      end
      if gid_string = vars["gid"]?
        gid = gid_string.to_u32
        group = libcrown.groups[gid].name
      elsif group = vars["system_group"]?
        gid = libcrown.to_gid group
      else
        group = '_' + @name
      end
    else
      libcrown = Libcrown.new nil
      uid = Process.uid
      gid = Process.gid
      user = libcrown.users[uid].name
      group = libcrown.users[gid].name
    end

    vars["uid"] = uid.to_s
    vars["gid"] = gid.to_s
    vars["system_user"] = user
    vars["system_group"] = group
    vars["package"] = pkg.package
    vars["version"] = pkg.version
    vars["basedir"] = @path.to_s
    vars["name"] = @name

    if env = pkg_file.env
      vars.merge! env
    end

    deps = Set(Prefix::Pkg).new
    pkg.build deps, false do
      simulate vars, deps, "add", confirmation, Log.output, &block
    end
    begin
      Log.info "adding to the system", @name
      raise "application directory already exists: #{@path}" if File.exists? @path.to_s

      # Create the new application
      Dir.mkdir @path.to_s
      create_application_dir shared

      # Copy configurations and data
      Log.info "copying configurations and data", @name

      copy_dir pkg.conf_path.to_s, conf_path.to_s
      copy_dir pkg.data_path.to_s, data_path.to_s
      Dir.mkdir logs_path.to_s

      # Build and add missing dependencies and copy library configurations
      install_deps deps, shared do |dep_pkg|
        if dep_config = dep_pkg.config
          Log.info "copying library configuration files", dep_pkg.name
          dep_conf_path = conf_path / dep_pkg.package
          Dir.mkdir_p dep_conf_path.to_s
          FileUtils.cp dep_pkg.config_file!.path, (dep_conf_path / File.basename(dep_pkg.config_file!.path)).to_s
        end
      end

      # Set configuration variables
      Log.info "setting configuration variables", @name
      each_config_key do |var|
        if var_value = vars[var]?
          set_config var, var_value
        end
      end

      write_configs
      set_permissions

      if (real_database = database?) && database_app && database_password
        Log.info "configure database", database_app.name
        real_database.ensure_root_password database_app
        real_database.create database_password
      end

      # Running the add task
      Log.info "running configuration tasks", @name

      if (tasks = pkg_file.tasks) && (add_task = tasks["add"]?)
        Dir.cd(@path.to_s) { Task.new(vars.dup, all_bin_paths).run add_task }
      end

      if website = @website
        Log.info "adding web site", website.file.to_s
        dir = website.file.dirname
        Dir.mkdir dir if !File.exists? dir

        app_uri = uri?
        case pkg_file.type
        when .html?
          website.root = app_path
        when .php?
          website.root = app_path
          website.fastcgi = vars["socket"]
        else
          website.proxy = app_uri.dup
        end

        website.hosts.clear
        if url = vars["url"]?
          website.hosts << URI.parse url
        else
          raise "no url address available for the web site"
        end
        @website = website
        website.write
        File.symlink website.file.to_s, web_site_file.to_s
      end

      # Create system user and group for the application
      if Process.root?
        libcrown = Libcrown.new
        add_group_member = false
        # Add a new group
        if !libcrown.groups.has_key? gid
          Log.info "system group created", group
          libcrown.add_group Libcrown::Group.new(group), gid
          add_group_member = true
        end

        system_user = libcrown.users[uid]?
        # Add a new user with `new_group` as its main group
        if !system_user
          system_user = Libcrown::User.new(
            name: user,
            gid: gid,
            gecos_comment: pkg_file.description,
            home_directory: data_path.to_s
          )
          libcrown.add_user system_user, uid
          Log.info "system user created", user
        else
          !libcrown.user_group_member? uid, gid
          add_group_member = true
        end
        libcrown.add_group_member(uid, gid) if add_group_member

        # Add the web server to the application group
        if web_server_uid && website?.try(&.root)
          libcrown.add_group_member web_server_uid, gid
        end

        # Save the modifications to the disk
        libcrown.write
        @owner = Owner.new system_user, libcrown.groups[gid]

        if add_service
          if database_app
            database_name = database_app.name
          end
          Log.info "creating system service", service.name
          service_create database_name
          service_enable
          Log.info service.type + " system service added", service.name
        end
        Utils.chown_r @path.to_s, uid, gid
      end

      Log.info "add completed", @path.to_s
      Log.info "application information", pkg_file.info
    rescue ex
      begin
        delete false { }
      ensure
        raise Exception.new "add failed - application deleted: #{@path}:\n#{ex}", ex
      end
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

  private def create_application_dir(shared : Bool)
    if !pkg_file.shared
      Log.warn "can't be shared, must be self-contained", pkg_file.package
      shared = false
    end

    if shared
      Log.info "creating symlinks from #{pkg.path}", @path.to_s
      File.symlink pkg.app_path.to_s, app_path.to_s
      File.symlink pkg.pkg_file.path.to_s, pkg_file.path.to_s
    else
      Log.info "copying from #{pkg.path}", @path.to_s
      FileUtils.cp_r pkg.app_path.to_s, app_path.to_s
      FileUtils.cp_r pkg.pkg_file.path.to_s, pkg_file.path.to_s
    end
  end

  def delete(confirmation : Bool = true, preserve_database : Bool = false, keep_user_group : Bool = false, &block)
    raise "application doesn't exist: #{@path}" if !File.exists? @path.to_s

    begin
      database.try(&.check_connection) if !preserve_database
    rescue ex
      raise Exception.new "either start the database or use the preseve database option:\n#{ex}", ex
    end

    # Checks
    if service = service?
      if service.exists?
        Log.info "a system service is found", @name
        service.check_delete
      else
        Log.warn "no system service found", @name
      end
    end

    if confirmation
      Log.output << "task: delete"
      Log.output << "\nname: " << @name
      Log.output << "\npackage: " << pkg_file.package
      Log.output << "\nbasedir: " << @path
      Log.output << "\nuser: " << owner.user.name
      Log.output << "\ngroup: " << owner.group.name
      service?.try do |service|
        Log.output << "\nservice: " << service.file
      end
      Log.output << '\n'
      return if !yield
    end

    Log.info "deleting", @path.to_s

    if service = service?
      if service.exists?
        Log.info "deleting system service", service.name
        service.delete
      end
    end

    if webserver = webserver?
      website = webserver.parse_site @name
      Log.info "deleting web site", website.file.to_s
      File.delete web_site_file.to_s
      File.delete website.file.to_s
      if output_file = website.log_file_output.to_s
        File.delete output_file if File.exists? output_file
      end
      if error_file = website.log_file_error.to_s
        File.delete error_file if File.exists? error_file
      end
      webserver.service.restart if webserver.service.run?
    end

    if Process.root?
      libcrown = Libcrown.new
      # Delete the web server from the group of the user
      if webserver
        libcrown.groups[file_info.group].users.delete libcrown.users[file_info.owner].name
      end
      if !keep_user_group
        libcrown.del_user file_info.owner if owner.user.name.starts_with? '_' + @name
        libcrown.del_group file_info.group if owner.group.name.starts_with? '_' + @name
      end
      libcrown.write
    end

    if !preserve_database && (app_database = database)
      Log.info "deleting database", app_database.user
      app_database.delete
    end

    Log.info "delete completed", @path.to_s
    self
  ensure
    FileUtils.rm_rf @path.to_s
  end

  def uri? : URI?
    if (host = get_config? "host") && (port = get_config? "port")
      URI.parse "//#{host}:#{port}"
    end
  end

  record Owner, user : Libcrown::User, group : Libcrown::Group

  getter file_info : File::Info do
    File.info @path.to_s
  end

  getter owner : Owner do
    libcrown = Libcrown.new nil
    Owner.new libcrown.users[file_info.owner], libcrown.groups[file_info.group]
  end
end
