require "./format"
require "dynany/yaml"

struct Config::YAML
  include Format
  getter data : ::YAML::Any

  def initialize(content : String, file : File? = nil)
    @data = ::YAML.parse content
  end

  def get(path : Array)
    @data[path]?
  end

  def set(path : Array, value)
    value = Utils.to_type value
    @data[path] = ::YAML::Any.new case value
    when Hash(String, String) then Hash(::YAML::Any, ::YAML::Any).new
    when Array(String)        then Array(::YAML::Any).new
    else                           value
    end
  end

  def del(path : Array)
    @data.delete path
  end

  def build : String
    @data.to_yaml
  end
end
