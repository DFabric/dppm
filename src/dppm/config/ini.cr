require "ini"

class Config::INI < Config::Format
  getter data : Hash(String, Hash(String, String))
  getter file : String
  getter space : Bool

  def initialize(@file : String)
    data = File.read @file
    @space = data.includes?(" = ") ? true : false
    @data = ::INI.parse data
  end

  def get(path : Array)
    case path.size
    when 1 then @data[path[0].to_s]?
    when 2
      if ini = @data[path[0].to_s]?
        ini[path[1].to_s]?
      end
    else
      raise "max key path exceeded: #{path.size}"
    end
  end

  def set(path : Array, value)
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
    end
    write
  end

  private def write
    File.write @file, ::INI.build(@data, @space)
  end
end
