struct Config::Pkg
  getter config : INI | JSON | YAML | CON
  getter pkg_config : Hash(String, String)

  def initialize(pkgdir : String, @pkg_config : Hash(String, String))
    if config_file = Dir[pkgdir + "/etc/config.*"][0]?
      @config = Config.new config_file
    else
      raise "file not found: #{pkgdir}/etc/config.*"
    end
  end

  def get(key : String)
    @config.get @pkg_config[key]
  end

  def set(key : String, value)
    @config.set @pkg_config[key], value
  end

  def del(key : String)
    @config.del @pkg_config[key]
  end
end
