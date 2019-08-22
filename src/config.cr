require "./config/*"
require "./utils"

module Config
  extend self
  alias Types = CON | INI | JSON | TOML | YAML

  # Yield the block when the file format is supported, and return the corresponding `Config::Types`, else raise.
  def read(file : Path) : Types
    to_type(file.extension.to_s.lchop) { File.read file.to_s }
  end

  # :ditto:
  def to_type(format : String, &block : Proc(String)) : Types
    to_type?(format) { yield } || raise "Unsupported file format: #{format}"
  end

  # Yield the block when the file format is supported, and return the corresponding `Config::Types`.
  def read?(file : Path) : Types?
    to_type?(file.extension.to_s.lchop) { File.read file.to_s }
  end

  # :ditto:
  def to_type?(format : String, &block : Proc(String)) : Types?
    case format
    when "con"         then Config::CON.new yield
    when "json"        then Config::JSON.new yield
    when "ini", "INI"  then Config::INI.new yield
    when "yml", "yaml" then Config::YAML.new yield
    when "toml"        then Config::TOML.new yield
    end
  end
end
