require "./program_data"

struct Prefix::App
  include ProgramData

  getter logs_dir : String,
    log_file_output : String,
    log_file_error : String

  getter pkg : Pkg do
    Pkg.new @prefix, File.basename(File.dirname(File.real_path(app_path))), nil, @pkg_file
  end

  getter service : Service::OpenRC | Service::Systemd do
    Host.service.new @name
  end

  getter? service : Service::OpenRC | Service::Systemd | Nil do
    Host.service.new(@name) if Host.service?
  end

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
  end

  def set_config(key : String, value)
    config.set pkg_file.config[key], value
  end

  def del_config(key : String)
    config.del pkg_file.config[key]
  end

  def real_app_path : String
    File.dirname File.real_path(app_path)
  end

  def log_file(error : Bool = false)
    error ? @log_file_error : @log_file_output
  end

  def set_permissions
    File.chmod conf_dir, 0o700
    File.chmod data_dir, 0o750
    File.chmod logs_dir, 0o700
  end

  def each_lib(&block : String ->)
    if Dir.exists? libs_dir
      Dir.each_child(libs_dir) do |lib_package|
        yield File.real_path(libs_dir + lib_package) + '/'
      end
    end
  end

  def env_vars : String
    String.build do |str|
      str << app_path << "/bin"
      if Dir.exists? libs_dir
        Dir.each_child(libs_dir) do |library|
          str << ':' << libs_dir << library << "/bin"
        end
      end
    end
  end
end
