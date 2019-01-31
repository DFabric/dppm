require "./config/*"
require "./utils"

module Config
  alias Types = Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML

  def self.new(file : String) : Format
    new file, File.extname(file).lchop
  end

  def self.new(file : String, format : String) : Format
    new?(file, format) || raise "not supported file format for #{file}: #{format}"
  end

  def self.new?(file : String) : Format?
    new? file, File.extname(file).lchop
  end

  def self.new?(file : String, format : String) : Format?
    case format
    when "con"         then Config::CON.new file
    when "json"        then Config::JSON.new file
    when "ini", "INI"  then Config::INI.new file
    when "yml", "yaml" then Config::YAML.new file
    when "toml"        then Config::TOML.new file
    end
  end
end
