struct Manager::Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    version : String

  def initialize(@package, @prefix)
    @pkgdir = Path.new(@prefix).pkg + package

    raise "package directory doesn't exists: " + @pkgdir if !Dir.exists? @pkgdir
    Log.info "getting package name", @pkgdir
    @name, @version = package.split '_'
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
