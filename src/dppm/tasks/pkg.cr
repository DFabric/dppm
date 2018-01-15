struct Pkg
  @pkg : YAML::Any
  @package : String

  def initialize(package)
    @package = package
    @pkg = YAML.parse File.read package + "/pkg.yml"
  end

  def version
    data = if @pkg["version"]["cmd"]?
             cmd = (@package + '/' + @pkg["version"]["cmd"].as_s).split ' '
             Exec.new(cmd[0], cmd[1..-1]).output
           elsif @pkg["version"]["path"]?
             @package + '/' + @pkg["version"]["src"].as_s
           else
             File.read @package + '/' + @pkg["version"]["src"].as_s
           end

    if @pkg["version"]["path"]?
      ConfFile.get data, Utils.to_array @pkg["version"]["path"].as_s
    else
      data.match(/#{@pkg["version"]["regex"].as_s}/).not_nil![0]
    end.to_s
  end
end
