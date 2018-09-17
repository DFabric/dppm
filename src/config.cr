require "./config/*"
require "./utils"

module Config
  def self.new(file : String)
    new file, File.extname(file).lchop
  end

  def self.new(file : String, format : String)
    case format
    when "ini", "INI"  then Config::INI.new file
    when "json"        then Config::JSON.new file
    when "yml", "yaml" then Config::YAML.new file
    else
      raise "not supported file format: " + format
    end
  end

  # The vars can't be modified
  struct Vars
    getter pkg : ::YAML::Any

    def initialize(@pkgdir)
      @pkg = YAML.parse(File.read pkgdir + "/pkg.yml")["vars"][key]
    end

    def get(key)
      file = @pkg[key].as_h["self"]? ? @pkg[key]["self"].as_s.to_i : 0
      get @pkgdir + '/' + file, Utils.to_array(@pkg)
    end
  end
end
