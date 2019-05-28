require "./format"
require "dynany/json"

struct Config::JSON
  include Format
  getter data : ::JSON::Any

  def initialize(@data : ::JSON::Any)
  end

  def self.new(content : String)
    new ::JSON.parse content
  end

  def get(path : Array)
    @data[path]?
  end

  def set(path : Array, value)
    value = to_type value
    @data[path] = ::JSON::Any.new case value
    when Hash(String, String) then Hash(String, ::JSON::Any).new
    when Array(String)        then Array(::JSON::Any).new
    else                           value
    end
  end

  def del(path : Array)
    @data.delete path
  end

  def build : String
    @data.to_pretty_json
  end
end
