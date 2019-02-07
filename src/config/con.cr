require "./format"
require "dynany/con"

struct Config::CON
  include Format
  getter data : ::CON::Any

  def initialize(content : String)
    @data = ::CON.parse content
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
  end

  def del(path : Array)
    @data.delete path
  end

  def build : String
    @data.to_pretty_con
  end
end
