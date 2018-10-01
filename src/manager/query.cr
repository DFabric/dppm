struct Manager::Query
  @pkgdir : String

  def initialize(@pkgdir)
  end

  def pkg(path)
    file = @pkgdir + "/pkg.yml"
    data = File.read file
    case path
    when "."
      data
    when "version"
      File.basename(File.dirname(File.real_path(file))).split('_').last
    else
      YAML.parse(data)[Utils.to_array path].to_yaml
    end
  end
end
