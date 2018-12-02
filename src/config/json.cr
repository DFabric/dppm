require "./format"
require "dynany/json"

struct Config::JSON
  include Format
  getter data : ::JSON::Any
  getter file : String

  def initialize(@file : String)
    data = File.read @file
    @data = ::JSON.parse data
  end

  def get(path : Array)
    @data[path]?
  end

  def set(path : Array, value)
    value = Utils.to_type value
    @data[path] = ::JSON::Any.new case value
    when .is_a? Hash(String, String) then Hash(String, ::JSON::Any).new
    when .is_a? Array(String)        then Array(::JSON::Any).new
    else
      value
    end
    write
  end

  def del(path : Array)
    @data.delete path
    write
  end

  private def write
    File.write @file, @data.to_pretty_json
  end
end
