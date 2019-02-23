require "./program_data"
require "libcrown"

struct Prefix::App
  include ProgramData

  getter logs_dir : String,
    log_file_output : String,
    log_file_error : String

  protected def initialize(@prefix : Prefix, @name : String, pkg_file : PkgFile? = nil)
    @path = @prefix.app + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
    @logs_dir = @path + "log/"
    @log_file_output = @logs_dir + "output.log"
    @log_file_error = @logs_dir + "error.log"
    @bin_path = app_path + "/bin"
  end

  getter password : String? do
    if File.exists? password_file
      File.read password_file
    end
  end

  getter password_file : String do
    conf_dir + ".password"
  end

  getter pkg : Pkg do
    Pkg.new @prefix, File.basename(File.dirname(File.real_path(app_path))), nil, @pkg_file
  end

  getter exec : Hash(String, String) do
    if !(exec = pkg_file.exec)
      libs.each do |library|
        exec ||= library.pkg.pkg_file.exec
      end
    end
    exec || raise "exec key not present in #{pkg_file.path}"
  end

  @service_intialized = false

  def service? : Service::OpenRC | Service::Systemd | Nil
    if !@service_intialized
      if service = Service.init?
        @service = service.new @name
      end
      @service_intialized = true
    end
    @service
  end

  getter service : Service::OpenRC | Service::Systemd do
    service? || raise "service not available"
  end

  getter service_path : String do
    conf_dir + "init"
  end

  getter service_file : String do
    service_path + '/' + service.type
  end

  def service_tap(&block : Service::OpenRC | Service::Systemd -> Service::OpenRC | Service::Systemd)
    @service = yield service
  end

  def service_create(user : String, group : String, database_name : String? = nil)
    Dir.mkdir_p service_path

    # Set service options
    service_tap do |service|
      service.config_tap do |config|
        config.user = user
        config.group = group
        config.directory = path
        config.description = pkg_file.description
        config.log_output = log_file_output
        config.log_error = log_file_error
        config.command = path + exec["start"]
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

  def service_enable
    service.link service_file
  end

  def database? : Database::MySQL | Nil
    @database
  end

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

      Database.new_database uri, user, type
    end
  end

  def database=(database_app : App)
    @database = Database.create @prefix, @name, database_app
  end

  private def config_from_libs(key : String, &block)
    libs.each do |library|
      if library_pkg_config_vars = library.pkg.pkg_file.config_vars
        if config_key = library_pkg_config_vars[key]?
          library.config.try do |lib_config|
            yield lib_config, config_key
          end
        end
      end
    end
  end

  private def keys_from_libs(&block)
    libs.each do |library|
      library.pkg.pkg_file.config_vars.try &.each_key do |key|
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
    config_from_pkg_file key do |config_file, config_key|
      config_export
      return config_file.get config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.get config_key
    end
    yield
  end

  def del_config(key : String)
    config_from_pkg_file key do |config_file, config_key|
      config_export
      return config_file.del config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.del config_key
    end
    raise "config key not found: " + key
  end

  def set_config(key : String, value)
    config_from_pkg_file key do |config_file, config_key|
      config_export
      return config_file.set config_key, value
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.set config_key, value
    end
    raise "config key not found: " + key
  end

  def each_config_key(&block : String ->)
    internal_each_config_key do |key|
      config_export
      yield key
    end
    keys_from_libs { |key| yield key }
  end

  def write_configs
    if app_config = config
      File.write config_file!.path, app_config.build
    end
    config_import
    libs.each do |library|
      if pkg_config = library.config
        File.write library.pkg.config_file!.path, pkg_config.build
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

        Exec.new command, args, output: Log.output, error: Log.error, chdir: @path, env: pkg_file.env do |process|
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

        output, error = Exec.new command, args, error: Log.error, chdir: @path, env: pkg_file.env do |process|
          raise "can't export configuration: " + full_command if !process.wait.success?
        end
        File.write config_file!.path, output.to_s
        config_file!.rewind
        @config = Config.new config_file!
      end
    end
  end

  private def update_configuration(&block)
    if origin_file = pkg_file.config_origin
      origin_file = @path + origin_file
      return if !File.exists? origin_file
      config_time = File.info(config_file!.path).modification_time
      origin_file_info = File.info(origin_file)
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

  def real_app_path : String
    File.dirname File.real_path(app_path)
  end

  def log_file(error : Bool = false)
    error ? @log_file_error : @log_file_output
  end

  def set_permissions
    File.chmod(libs_dir, 0o700) if Dir.exists? libs_dir
    File.chmod(app_path, 0o750) if !File.symlink? app_path
    File.chmod conf_dir, 0o700
    File.chmod @path, 0o750
    File.chmod logs_dir, 0o750
    File.chmod data_dir, 0o750
  end

  def path_env_var : String
    String.build do |str|
      str << @bin_path
      libs.each do |library|
        str << ':' << library.pkg.bin_path
      end
    end
  end

  getter web_site_file : String do
    conf_dir + "web-site"
  end

  def webserver? : Prefix::App?
    if File.exists? web_site_file
      @prefix.new_app File.basename(File.dirname((File.dirname(File.dirname(File.real_path(web_site_file))))))
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
  def new_website(app_name : String, build_conf_dir : String) : WebSite::Caddy
    raise "Web server doesn't exists: #{@path}" if !Dir.exists? @path
    default_site_file = build_conf_dir + "web/" + pkg_file.package
    site = parse_site app_name, default_site_file

    # Add security headers
    if !File.exists? default_site_file
      site.headers["Strict-Transport-Security"] = "max-age=31536000;"
      site.headers["X-XSS-Protection"] = "1; mode=block"
      site.headers["X-Content-Type-Options"] = "nosniff"
      site.headers["X-Frame-Options"] = "DENY"
      site.headers["Content-Security-Policy"] = "frame-ancestors 'none';"
    end
    site.log_file_error = logs_dir + app_name + "-error.log"
    site.log_file_output = logs_dir + app_name + "-output.log"
    site.file = conf_dir + "sites/" + app_name
    site
  end

  protected def parse_site(app_name : String, file : String? = nil) : WebSite::Caddy
    file ||= conf_dir + "sites/" + app_name
    case pkg_file.package
    when "caddy" then WebSite::Caddy.new file
    else              raise "unsupported web server: " + pkg_file.package
    end
  end

  def add(
    vars : Hash(String, String),
    uid : UInt32,
    gid : UInt32,
    user : String,
    group : String,
    add_service : Bool = true,
    app_database : Prefix::App? = nil,
    database_password : String? = nil,
    web_server_uid : UInt32? = nil
  )
    # Set configuration variables
    Log.info "setting configuration variables", @name
    each_config_key do |var|
      if var == "socket"
        next
      elsif variable_value = vars[var]?
        set_config var, variable_value
      end
    end

    write_configs
    set_permissions

    if (real_database = database?) && app_database && database_password
      Log.info "configure database", app_database.name
      real_database.ensure_root_password app_database
      real_database.create database_password
    end

    # Running the add task
    Log.info "running configuration tasks", @name

    if (tasks = pkg_file.tasks) && (add_task = tasks["add"]?)
      Dir.cd(@path) { Task.new(vars.dup, all_bin_paths).run add_task }
    end

    if website = @website
      Log.info "adding web site", website.file
      dir = File.dirname website.file
      Dir.mkdir dir if !File.exists? dir

      app_uri = uri?
      if File.exists? conf_dir + "php"
        website.root = app_path
        website.fastcgi = @path + "socket"
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
      File.symlink website.file, web_site_file
    end

    # Create system user and group for the application
    if Process.root?
      if add_service
        if app_database
          database_name = app_database.name
        end
        Log.info "creating system service", service.name
        service_create user, group, database_name
        service_enable
        Log.info service.type + " system service added", service.name
      end

      libcrown = Libcrown.new
      add_group_member = false
      # Add a new group
      if !libcrown.groups.has_key? gid
        Log.info "system group created", group
        libcrown.add_group Libcrown::Group.new(group), gid
        add_group_member = true
      end

      if !libcrown.users.has_key? uid
        # Add a new user with `new_group` as its main group
        new_user = Libcrown::User.new(
          name: user,
          gid: gid,
          gecos_comment: pkg_file.description,
          home_directory: data_dir
        )
        libcrown.add_user new_user, uid
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
      Utils.chown_r path, uid, gid
    end

    Log.info "add completed", @path
    Log.info "application information", pkg_file.info
  end

  def delete(preserve_database : Bool = false, keep_user_group : Bool = false)
    Log.info "deleting", @path

    if service = service?
      if service.exists?
        Log.info "deleting system service", service.name
        service.delete
      end
    end

    if !preserve_database && (app_database = database)
      Log.info "deleting database", app_database.user
      app_database.delete
    end

    if webserver = webserver?
      website = webserver.parse_site @name
      Log.info "deleting web site", website.file
      File.delete web_site_file
      File.delete website.file
      if output_file = website.log_file_output
        File.delete output_file if File.exists? output_file
      end
      if error_file = website.log_file_error
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
    FileUtils.rm_rf @path

    Log.info "delete completed", @path
  end

  def uri? : URI?
    if (host = get_config? "host") && (port = get_config? "port")
      URI.parse "//#{host}:#{port}"
    end
  end

  record Owner, user : Libcrown::User, group : Libcrown::Group

  getter file_info : File::Info do
    File.info @path
  end

  getter owner : Owner do
    libcrown = Libcrown.new nil
    Owner.new libcrown.users[file_info.owner], libcrown.groups[file_info.group]
  end
end
