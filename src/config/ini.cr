require "./format"
require "ini"

struct Config::INI
  module Helper
    # Returns a section key, and a sub-key if present.
    # Raises if the path is invalid.
    private def ini_key_path(path : Array) : String | Tuple(String, String)
      case path.size
      when 0 then raise "Key path empty"
      when 1 then path[0].to_s
      when 2 then {path[0].to_s, path[1].to_s}
      else        raise "Max key path exceeded: #{path.size}"
      end
    end

    def del(path : Array)
      case key_path = ini_key_path path
      when String then @data.delete key_path
      else             @data[key_path[0]].delete key_path[1]
      end
    end
  end

  include Helper
  include Format
  getter data : Hash(String, Hash(String, String))

  def initialize(@data : Hash(String, Hash(String, String)))
  end

  def self.new(content : String)
    new ::INI.parse content
  end

  def get(path : Array)
    case key_path = ini_key_path path
    when String then @data[key_path]?
    else             @data[key_path[0]]?.try &.[key_path[1]]?
    end
  end

  def set(path : Array, value)
    case key_path = ini_key_path path
    when String then @data[""][key_path] = value.to_s
    else             @data[key_path[0]][key_path[1]] = value.to_s
    end
  end

  def build : String
    ::INI.build @data, true
  end
end
