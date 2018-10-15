struct Manager::Package::Clean
  getter prefix : String,
    pkgdir : String,
    packages = Set(String).new

  def initialize(@prefix)
    list = List.new @prefix
    @pkgdir = list.path.pkg
    Log.info "retrieving available packages", @pkgdir
    list.pkg { |pkg| @packages << pkg }
    Log.info "excluding used packages by applications", list.path.app
    list.app do |app|
      app_path = list.path.app + app
      @packages.delete File.basename(File.real_path(app_path + "/app").rstrip("app"))
      lib_path = app_path + "/lib/"
      Dir.each_child lib_path do |lib_package|
        @packages.delete File.basename(File.real_path lib_path + lib_package)
      end
    end
  end

  def simulate
    String.build do |str|
      str << "\npkgdir: " << @pkgdir
      str << "\nunused packages: \n"
      @packages.each do |pkg|
        str << pkg << '\n'
      end
    end
  end

  def run
    Log.info "deleting packages", @pkgdir
    @packages.each do |pkg|
      path = @pkgdir + '/' + pkg
      FileUtils.rm_rf path
      Log.info "package deleted", pkg
    end
    Log.info "packages cleaned", @pkgdir
    self
  end
end
