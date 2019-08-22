require "./format"
require "ini"

# Basic ugly 2-level toml parser for TiDB configuration
struct Config::TOML
  include Format
  include INI::Helper
  getter data : Hash(String, Hash(String, String))

  def initialize(@data : Hash(String, Hash(String, String)))
  end

  def self.new(content : String)
    new ::INI.parse content
  end

  def get(path : Array)
    case key_path = ini_key_path path
    when String then @data[key_path]?
    else
      if section = @data[key_path[0]]?
        internal_to_type section[key_path[1]]?
      end
    end
  end

  def set(path : Array, value)
    value = to_type value
    value = '"' + value + '"' if value.is_a? String
    case key_path = ini_key_path path
    when String then @data[""][key_path] = value.to_s
    else             @data[key_path[0]][key_path[1]] = value.to_s
    end
  end

  private def internal_to_type(string : String?)
    if string.is_a? String
      if result = string.lchop?('"').try &.rchop?('"')
        result
      elsif string == "true"
        true
      elsif string == "false"
        false
      elsif int = string.to_i64?
        int
      elsif float = string.to_f64?
        float
      else
        string
      end
    end
  end

  def build : String
    ::INI.build(@data, space: true).lchop "[]\n"
  end
end
