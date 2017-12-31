struct Tasks::Delete
  @package : String
  @prefix : String
  @pkgdir : String
  @pkgdir : String
  @service = false

  def initialize(vars, &log : String, String, String -> Nil)
    @log = log
    @prefix = vars["prefix"]
    @package = vars["package"]
    @pkgdir = @prefix + '/' + @package

    # Checks
    Tasks.pkg_exists? @pkgdir
    service_path = HOST.service.file @package
    if File.exists?(service_path) &&
       File.real_path(service_path) == @pkgdir + "/etc/init/" + HOST.service.name.downcase
      log.call "INFO", "a system service is found", @package
      @service = true
    elsif !@package.includes? '_'
      log.call "WARN", "no system service found", @package
    end
  end

  def simulate
    String.build do |str|
      str << "\npackage: " << @package
      str << "\nprefix: " << @prefix
      str << "\nservice: " << HOST.service.file @package if @service
    end
  end

  def run
    Service.delete @package, &@log if @service
    FileUtils.rm_rf @prefix + '/' + @package
    @log.call "INFO", "deleted", @prefix + '/' + @package
  end
end
