struct Manager::Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    version : String

  def initialize(@package, @prefix)
    @pkgdir = Path.new(@prefix).package package

    # Checks
    Manager.pkg_exists? @pkgdir
    Log.info "getting package name", @pkgdir + "/pkg.yml"
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
  end
end
