struct Manager::Package::Delete
  getter pkg : Prefix::Pkg

  def initialize(prefix : Prefix, package : String, version : String?)
    @pkg = prefix.new_pkg package, version
    raise "package doesn't exist: " + @pkg.path if !File.exists? @pkg.path

    # Check if the package is still in use by an application
    Log.info "check packages in use", @pkg.path
    prefix.each_app do |app|
      if app.real_app_path + '/' == @pkg.path
        raise "application package `#{package}` still in use by an application: " + app.name
      end
      app.libs.each do |library|
        if @pkg.path == library.pkg.path
          raise "library package `#{package}` still in use by an application: " + app.name
        end
      end
    end
  end

  def simulate(io = Log.output)
    io << "task: delete"
    io << "\npackage: " << @pkg.package
    io << "\nversion: " << @pkg.version
    io << "\nbasedir: " << @pkg.path
    io << '\n'
  end

  def run
    @pkg.delete
    self
  end
end
