require "./program_data"

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
      if config_vars.has_key? "database_address"
        uri = URI.parse "//#{get_config("database_address")}"
      elsif config_vars.has_key? "database_host"
        uri = URI.new(
          host: get_config("database_host").to_s,
          port: get_config("database_port").to_s.to_i?,
        )
      end
      if config_vars.has_key? "database_type"
        type = get_config("database_type").to_s
      end
    end

    if !type && (databases = pkg_file.databases)
      type = databases.first.first
    else
      return
    end
    return if !Database.supported? type

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
    config_from_pkg_file key do |config_file, config_key|
      config_export
      return config_file.get config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.get config_key
    end
    raise "config key not found: " + key
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

  def add(vars : Hash(String, String))
    if (tasks = pkg_file.tasks) && (add_task = tasks["add"]?)
      Dir.cd(@path) { Task.new(vars.dup, all_bin_paths).run add_task }
    end
  end
end
