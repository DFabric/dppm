struct Pkg
  @package : String
  @pkg = YAML.parse File.read @package + "/pkg.yml"

  def initialize(@package)
  end

  def version
    data = if @pkg["version"]["path"]?
             @package + '/' + @pkg["version"]["src"].as_s
           else
             File.read @package + '/' + @pkg["version"]["src"].as_s
           end

    if path = @pkg["version"]["path"].as_s?
      ConfFile.get data, Utils.to_array path
    elsif data =~ /#{@pkg["version"]["regex"].as_s}/
      $0
    else
      raise "can't obtain the version"
    end.to_s
  end
end
