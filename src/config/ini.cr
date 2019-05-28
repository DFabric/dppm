require "./format"
require "ini"

struct Config::INI
  include Format
  getter data : Hash(String, Hash(String, String))

  def initialize(@data : Hash(String, Hash(String, String)))
  end

  def self.new(content : String)
    new ::INI.parse content
  end

  def get(path : Array)
    case path.size
    when 1 then @data[path[0].to_s]?
    when 2
      if ini = @data[path[0].to_s]?
        ini[path[1].to_s]?
      end
    else raise "max key path exceeded: #{path.size}"
    end
  end

  def set(path : Array, value)
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
    ::INI.build @data, true
  end
end
