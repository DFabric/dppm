require "./format"
require "ini"

# Basic ugly 2-level toml parser for TiDB configuration
struct Config::TOML
  include Format
  getter data : Hash(String, Hash(String, String))

  def initialize(@data : Hash(String, Hash(String, String)))
  end

  def self.new(content : String)
    new ::INI.parse content
  end

  def get(path : Array)
    case path.size
    when 1
      if toml = @data[""]?
        internal_to_type toml[path[0].to_s]?
      end
    when 2
      if toml = @data[path[0].to_s]?
        internal_to_type toml[path[1].to_s]?
      end
    else
      raise "max key path exceeded: #{path.size}"
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

  def set(path : Array, value)
    value = to_type value
    value = '"' + value + '"' if value.is_a? String
    case path.size
    when 1 then @data[""][path[0].to_s] = value.to_s
    when 2 then @data[path[0].to_s][path[1].to_s] = value.to_s
    else        raise "max key path exceeded: #{path.size}"
    end
  end

  def del(path : Array)
    case path.size
    when 1 then @data.delete path[0].to_s
    when 2 then @data[path[0].to_s].delete path[1].to_s
    else        raise "max key path exceeded: #{path.size}"
    end
  end

  def build : String
    ::INI.build(@data, space: true).lchop "[]\n"
  end
end
