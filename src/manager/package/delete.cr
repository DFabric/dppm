struct Manager::Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    version : String
  @path : Path

  def initialize(@package, @prefix)
    @path = Path.new @prefix
    @pkgdir = @path.pkg + package
    raise "package directory doesn't exists: " + @pkgdir if !Dir.exists? @pkgdir

    Log.info "getting package name", @pkgdir
    @name, @version = package.split '_'

    # Check if the package is still in use by an application
    Dir.each_child @path.app do |app|
      app_path = @path.app + app
      lib_path = app_path + "/lib/" + @name
      app_path = app_path + "/app"
      if File.symlink?(lib_path) && File.real_path(lib_path) == @pkgdir
        raise "library package `#{package}` still in use by an application: " + File.basename app
      elsif File.symlink?(app_path) && File.real_path(app_path) == @pkgdir + "/app"
        raise "application package `#{package}` still in use by an application: " + File.basename app
      end
    end
  end

  def simulate
    String.build do |str|
      str << "\nname: " << @name
      str << "\nversion: " << @version
      str << "\npkgdir: " << @pkgdir
    end
  end

  def run
    Log.info "deleting", @pkgdir
    FileUtils.rm_rf @pkgdir
    Log.info "package deleted", @pkgdir
    self
  end
end
