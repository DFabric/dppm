struct Config::Pkg
  getter pkg : ::YAML::Any
  getter config : ::Config::INI | ::Config::JSON | ::Config::YAML

  def initialize(pkgdir)
    raise "file not found: #{pkgdir}/etc/config.*" unless config_file = Dir[pkgdir + "/etc/config.*"][0]?
    @config = Config.new config_file
    @pkg = ::YAML.parse(File.read pkgdir + "/pkg.yml")["config"]
  end

  def get(key : String)
    @config.get @pkg[key].as_s
  end

  def set(key : String, value)
    @config.set @pkg[key].as_s, value
  end

  def del(key : String)
    @config.del @pkg[key].as_s
  end
end
