module Package
  def info(prefix, application, path)
    file = ::Package::Path.new(prefix).app + '/' + application + "/pkg.yml"
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
