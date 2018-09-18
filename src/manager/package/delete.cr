struct Manager::Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    version : String,
    pkg : YAML::Any

  def initialize(@package, @prefix)
    @path = Path.new @prefix
    @name, @version = @package.split '_'
    @pkgdir = @path.pkg + '/' + @package

    # Checks
    Manager.pkg_exists? @pkgdir
    Log.info "getting package name", @pkgdir + "/pkg.yml"
    @pkg = YAML.parse(File.read(@pkgdir + "/pkg.yml"))
    @package = @pkg["package"].as_s
  end

  def simulate
    String.build do |str|
      str << "\npackage: " << @package
      str << "\nname: " << @name
      str << "\nversion: " << @version
      str << "\nprefix: " << @prefix
      str << "\npkgdir: " << @pkgdir
    end
  end

  def run
    Log.info "deleting", @pkgdir
    FileUtils.rm_rf @pkgdir
    Log.info "package deleted", @pkgdir
  end
end
