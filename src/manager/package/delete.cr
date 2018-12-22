struct Manager::Package::Delete
  getter pkg : Prefix::Pkg

  def initialize(prefix : Prefix, package : String)
    @pkg = prefix.new_pkg package

    # Check if the package is still in use by an application
    Log.info "check packages in use", @pkg.path
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
      str << "\npackage: " << @pkg.name
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
