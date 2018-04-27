struct Pkg
  @package : String
  @pkg = YAML.parse File.read @package + "/pkg.yml"

  def initialize(@package)
  end

  def version
    data = if cmd = @pkg["version"]["cmd"].as_s?
             cmd = (@package + '/' + cmd).split ' '
             Exec.new(cmd[0], cmd[1..-1]).output
           elsif @pkg["version"]["path"]?
             @package + '/' + @pkg["version"]["src"].as_s
           else
             File.read @package + '/' + @pkg["version"]["src"].as_s
           end

    if path = @pkg["version"]["path"].as_s?
      ConfFile.get data, Utils.to_array path
    else
      data.match(/#{@pkg["version"]["regex"].as_s}/).not_nil![0]
    end.to_s
  end
end
