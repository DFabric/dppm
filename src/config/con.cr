require "./format"
require "dynany/con"

struct Config::CON
  include Format
  getter data : ::CON::Any
  getter file : String

  def initialize(@file : String)
    data = File.read @file
    @data = ::CON.parse data
  end

  def get(path : Array)
    @data[path]?
  end

  def set(path : Array, value)
    value = Utils.to_type value
    @data[path] = ::CON::Any.new case value
    when Hash(String, String) then Hash(String, ::CON::Any).new
    when Array(String)        then Array(::CON::Any).new
    else                           value
    end
    write
  end

  def del(path : Array)
    @data.delete path
    write
  end

  private def write
    File.write @file, @data.to_pretty_con
  end
end
