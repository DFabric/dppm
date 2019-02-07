require "./config/*"
require "./utils"

module Config
  alias Types = Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML

  def self.new(file : File) : Format
    new file, File.extname(file.path).lchop
  end

  def self.new(file : File, format : String) : Format
    new?(file, format) || raise "not supported file format for #{file}: #{format}"
  end

  def self.new?(file : File) : Format?
    new? file, File.extname(file.path).lchop
  end

  def self.new?(file : File, format : String) : Format?
    case format
    when "con"         then Config::CON.new file.gets_to_end
    when "json"        then Config::JSON.new file.gets_to_end
    when "ini", "INI"  then Config::INI.new file.gets_to_end
    when "yml", "yaml" then Config::YAML.new file.gets_to_end
    when "toml"        then Config::TOML.new file.gets_to_end
    end
  end
end
