struct Pkg
  @pkg : YAML::Any
  @package : String

  def initialize(package)
    @package = package
    @pkg = YAML.parse File.read package + "/pkg.yml"
  end

  def version
    data = if @pkg["version"]["current"]["cmd"]?
             cmd = (@package + '/' + @pkg["version"]["current"]["cmd"].as_s).split ' '
             Exec.new(cmd[0], cmd[1..-1]).output
           else
             @pkg["version"]["current"]["src"].as_s
           end

    if @pkg["version"]["current"]["path"]?
      ConfFile.get data, Utils.to_array @pkg["version"]["current"]["path"].as_s
    else
      data.match(/#{@pkg["version"]["current"]["regex"].as_s}/).not_nil![0]
    end.to_s
  end
end
