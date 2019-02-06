require "./format"
require "dynany/json"

struct Config::JSON
  include Format
  getter data : ::JSON::Any
  getter file : String

  def initialize(@file : String)
    @data = parse File.read(@file)
  end

  def parse(content : String) : ::JSON::Any
    @data = ::JSON.parse content
  end

  def get(path : Array)
    @data[path]?
  end

  def set(path : Array, value)
    value = Utils.to_type value
    @data[path] = ::JSON::Any.new case value
    when Hash(String, String) then Hash(String, ::JSON::Any).new
    when Array(String)        then Array(::JSON::Any).new
    else                           value
    end
  end

  def del(path : Array)
    @data.delete path
  end

  def write
    File.write @file, @data.to_pretty_json
  end
end
