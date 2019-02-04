require "./program_data"

struct Prefix::App
  include ProgramData

  getter logs_dir : String,
    log_file_output : String,
    log_file_error : String

  record Lib, relative_path : String, pkg : Prefix::Pkg, config : Config::Types?

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

  getter libs : Array(Lib) do
    libs = Array(Lib).new
    return libs if !Dir.exists? libs_dir

    Dir.each_child libs_dir do |lib_package|
      relative_path = libs_dir + lib_package
      lib_pkg = @prefix.new_pkg File.basename(File.real_path(relative_path))
      config_file = nil
      if Dir.exists?(conf_lib_dir = conf_dir + lib_pkg.package)
        Dir.each_child conf_lib_dir do |file|
          config_file = Config.new? conf_lib_dir + '/' + file
        end
      end
      libs << Lib.new relative_path, lib_pkg, config_file
    end

    libs
  end

  getter password : String? do
    if File.exists? password_file
      File.read password_file
    end
  end

  getter password_file : String do
    conf_dir + "password"
  end

  getter pkg : Pkg do
    Pkg.new @prefix, File.basename(File.dirname(File.real_path(app_path))), nil, @pkg_file
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
    if !(exec = pkg_file.exec)
      libs.each do |library|
        exec ||= library.pkg.pkg_file.exec
      end
    end
    exec || raise "exec key not present in #{pkg_file.path}"
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
    if config_vars = pkg_file.config.vars
      if config_vars.has_key? "database_address"
        uri = URI.parse "//#{get_config("database_address")}"
      elsif config_vars.has_key? "database_host"
        uri = URI.new(
          host: get_config("database_host").to_s,
          port: get_config("database_port").to_s.to_i?,
        )
      end
    end
    return if !uri

    type = get_config("database_type").to_s
    return if !Database.supported? type

    uri.password = get_config("database_password").to_s
    uri.user = user = get_config("database_user").to_s

    Database.new_database uri, user, type
  end

  def database=(database_app : App)
    @database = Database.create @prefix, @name, database_app
  end

  private def config_from_libs(key : String, &block)
    libs.each do |library|
      if library_pkg_config_vars = library.pkg.pkg_file.config.vars
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
      library.pkg.pkg_file.config.vars.try &.each_key do |key|
        yield key
      end
    end
  end

  def get_config(key : String)
    config_from_pkg_file key do |config_file, config_key|
      return config_file.get config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.get config_key
    end
    raise "config key not found: " + key
  end

  def del_config(key : String)
    config_from_pkg_file key do |config_file, config_key|
      return config_file.del config_key
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.del config_key
    end
    raise "config key not found: " + key
  end

  def set_config(key : String, value)
    config_from_pkg_file key do |config_file, config_key|
      return config_file.set config_key, value
    end
    config_from_libs key do |lib_config, config_key|
      return lib_config.set config_key, value
    end
    raise "config key not found: " + key
  end

  def each_config_key(&block : String ->)
    internal_each_config_key { |key| yield key }
    keys_from_libs { |key| yield key }
  end

  def write_configs
    config.try &.write
    libs.each &.pkg.config.try &.write
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
end
