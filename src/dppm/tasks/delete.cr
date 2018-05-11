struct Tasks::Delete
  @package : String
  @prefix : String
  @pkgdir : String
  @pkgdir : String
  @service_path : String
  @service = false

  def initialize(vars)
    @prefix = vars["prefix"]
    @package = vars["package"].gsub(':', '_')
    @pkgdir = @prefix + '/' + @package

    # Checks
    Tasks.pkg_exists? @pkgdir
    @service_path = Localhost.service.system.new(@package).file
    if File.exists?(@service_path) &&
       File.real_path(@service_path) == @pkgdir + "/etc/init/" + Localhost.service.name.downcase
      Log.info "a system service is found", @package
      @service = true
    elsif !@package.includes? '_'
      Log.warn "no system service found", @package
    end
  end

  def simulate
    String.build do |str|
      str << "\npackage: " << @package
      str << "\nprefix: " << @prefix
      str << "\nservice: " << @service_path if @service
    end
  end

  def run
    Localhost.service.delete @package if @service
    FileUtils.rm_rf @prefix + '/' + @package
    Log.info "deleted", @prefix + '/' + @package
  end
end
