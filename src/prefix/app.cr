require "./program_data"

struct Prefix::App
  include ProgramData

  getter log_dir : String,
    log_file_output : String,
    log_file_error : String

  protected def initialize(@prefix : Prefix, @name : String, pkg_file : PkgFile? = nil)
    @path = @prefix.app + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
    @log_dir = @path + "log/"
    @log_file_output = @log_dir + "output.log"
    @log_file_error = @log_dir + "error.log"
  end

  def set_config(key : String, value)
    config.set pkg_file_config[key], value
  end

  def del_config(key : String)
    config.del pkg_file_config[key]
  end

  def real_app_dir : String
    File.dirname(File.real_path(app_dir))
  end

  def log_file(error : Bool = false)
    error ? @log_file_error : @log_file_output
  end

  def set_permissions
    File.chmod conf, 0o700
    File.chmod data, 0o750
    File.chmod log_dir, 0o700
  end

  def each_lib(&block : String -> _)
    if Dir.exists? self.lib
      Dir.each_child(self.lib) do |lib_package|
        yield File.real_path self.lib + '/' + lib_package
      end
    end
  end

  def env_vars : String
    String.build do |str|
      str << app_dir << "/bin"
      if Dir.exists? self.lib
        Dir.each_child(self.lib) do |library|
          str << ':' << self.lib << '/' << library << "/bin"
        end
      end
    end
  end
end
