struct Manager::Package::Delete
  getter package : String,
    name : String,
    pkg : Prefix::Pkg,
    version : String

  def initialize(prefix : Prefix, @package : String)
    @pkg = prefix.new_pkg @package

    Log.info "getting package name", @pkg.path
    @name, @version = package.split '_'

    # Check if the package is still in use by an application
    prefix.each_app do |app|
      if app.real_app_path + '/' == @pkg.path
        raise "application package `#{package}` still in use by an application: " + app.name
      end
      app.each_lib do |app_lib|
        if app_lib == @pkg.path
          raise "library package `#{package}` still in use by an application: " + app.name
        end
      end
    end
  end

  def simulate
    String.build do |str|
      str << "\nname: " << @name
      str << "\nversion: " << @version
      str << "\nbasepath: " << @pkg.path
    end
  end

  def run
    Log.info "deleting", @pkg.path
    FileUtils.rm_rf @pkg.path
    Log.info "package deleted", @pkg.path
    self
  end
end
