require "./config/*"
require "./utils"

module Config
  def self.new(file : String)
    new file, File.extname(file).lchop
  end

  def self.new(file : String, format : String) : Format
    case format
    when "con"         then Config::CON.new file
    when "json"        then Config::JSON.new file
    when "ini", "INI"  then Config::INI.new file
    when "yml", "yaml" then Config::YAML.new file
    when "toml"        then Config::TOML.new file
    else                    raise "not supported file format: " + format
    end
  end
end
