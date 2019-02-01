struct Manager::Package::Clean
  getter prefix : Prefix,
    packages : Set(String) = Set(String).new

  def initialize(@prefix : Prefix)
    Log.info "retrieving available packages", @prefix.pkg
    @prefix.each_pkg { |pkg| @packages << pkg.name }
    Log.info "excluding used packages by applications", @prefix.pkg
    @prefix.each_app do |app|
      @packages.delete File.basename(app.real_app_path)
      app.libs.each do |library|
        @packages.delete library.pkg.name
      end
    end
  end

  def simulate(io = Log.output)
    io << "task: clean"
    io << "\nbasedir: " << @prefix.pkg
    io << "\nunused packages: \n"
    @packages.each do |pkg|
      io << pkg << '\n'
    end
  end

  def run
    Log.info "deleting packages", @prefix.pkg
    @packages.each do |pkg|
      pkg_prefix = prefix.new_pkg pkg
      FileUtils.rm_rf pkg_prefix.path
      Log.info "package deleted", pkg
    end
    Log.info "packages cleaned", @prefix.pkg
    self
  end
end
