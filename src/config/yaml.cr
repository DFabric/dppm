require "./format"
require "dynany/yaml"

struct Config::YAML
  include Format
  getter data : ::YAML::Any
  getter file : String

  def initialize(@file : String)
    @data = read
  end

  def read : ::YAML::Any
    @data = ::YAML.parse File.read(@file)
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
    write
  end

  def del(path : Array)
    @data.delete path
    write
  end

  private def write
    File.write @file, @data.to_yaml
  end
end
