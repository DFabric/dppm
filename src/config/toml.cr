require "./format"
require "ini"

# Basic ugly 2-level toml parser for TiDB configuration
struct Config::TOML
  include Format
  getter data : Hash(String, Hash(String, String))
  getter file : String

  def initialize(@file : String)
    data = File.read @file
    @data = ::INI.parse data
  end

  def get(path : Array)
    case path.size
    when 1
      if toml = @data[""]?
        to_type toml[path[0].to_s]?
      end
    when 2
      if toml = @data[path[0].to_s]?
        to_type toml[path[1].to_s]?
      end
    else
      raise "max key path exceeded: #{path.size}"
    end
  end

  private def to_type(result : String?)
    if result.is_a?(String)
      if result.starts_with?('"') && result.ends_with?('"')
        return result[1..-2]
      elsif result == "true"
        true
      elsif result == "false"
        false
      elsif int = result.to_i64?
        int
      elsif float = result.to_f64?
        float
      else
        result
      end
    end
  end

  def set(path : Array, value)
    value = to_type value
    value = '"' + value + '"' if value.is_a? String
    case path.size
    when 1 then @data[""][path[0].to_s] = value.to_s
    when 2 then @data[path[0].to_s][path[1].to_s] = value.to_s
    else
      raise "max key path exceeded: #{path.size}"
    end
    write
  end

  def del(path : Array)
    case path.size
    when 1 then @data.delete path[0].to_s
    when 2 then @data[path[0].to_s].delete path[1].to_s
    else
      raise "max key path exceeded: #{path.size}"
    end
    write
  end

  private def write
    File.write @file, ::INI.build(@data, space: true).lstrip("[]\n")
  end
end
