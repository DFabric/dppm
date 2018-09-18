struct Manager::Info
  @path : String
  @package : String

  def initialize(path, @package)
    @path = path + '/' + @package + '/'
  end

  def self.app_cli(prefix, package, path)
    new(Path.new(prefix).app, package).pkg path
  end

  def self.pkg_cli(prefix, package, path)
    new(Path.new(prefix).pkg, package).pkg path
  end

  def self.src_cli(prefix, package, path)
    new(Path.new(prefix).src, package).pkg path
  end

  def pkg(path)
    file = @path + "pkg.yml"
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
