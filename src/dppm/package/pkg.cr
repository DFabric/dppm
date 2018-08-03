struct Pkg
  @package : String
  @pkg = YAML.parse File.read @package + "/pkg.yml"

  def initialize(@package)
  end

  def version
    if path = @pkg["version"]["path"].as_s?
      data = @package + '/' + @pkg["version"]["src"].as_s
      ConfFile.get data, path
    else
      data = File.read @package + '/' + @pkg["version"]["src"].as_s
      if data =~ /#{@pkg["version"]["regex"].as_s}/
        $0
      else
        raise "can't obtain the version"
      end
    end
  end
end
