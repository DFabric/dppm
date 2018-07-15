require "ini"
require "json"
require "yaml"

module ConfFile
  extend self

  def get(file, keys : Array, format = File.extname(file).lchop)
    data = File.read file
    data = case format.empty? ? File.extname(file) : format
           when "ini", "INI"  then INI.parse data
           when "json"        then JSON.parse data
           when "yml", "yaml" then YAML.parse data
           else
             raise "not supported file format: " + format
           end
    keys.each do |key|
      return unless data = data[key]?
    end
    data
  end

  def set(file, keys : Array, value, format = File.extname(file).lchop)
    data = File.read file
    case format.empty? ? File.extname(file) : format
    when "ini", "INI"
      space = data.includes?(" = ") ? true : false
      File.write file, INI.build(ini(INI.parse(data), keys, value), space)
    when "json"
      val = JSON::Any.new case Utils.to_type value
      when .is_a? Hash(String, String) then Hash(String, JSON::Any).new
      when .is_a? Array(String)        then Array(JSON::Any).new
      else
        value
      end

      File.write file, set_json(JSON.parse(data), keys, val).to_pretty_json
    when "yml", "yaml"
      val = YAML::Any.new case Utils.to_type value
      when .is_a? Hash(String, String) then Hash(YAML::Any, YAML::Any).new
      when .is_a? Array(String)        then Array(YAML::Any).new
      else
        value
      end

      File.write file, set_json(YAML.parse(data), keys.map { |str| YAML::Any.new str }, val).to_yaml
    else
      raise "not supported file format: " + format
    end
  end

  def del(file, keys : Array, format = File.extname(file).lchop)
    data = File.read file

    case format
    when "ini", "INI"
      data = INI.parse data
      case keys.size
      when 1 then data.delete keys[0]
      when 2 then data[keys[0]].to_h.delete keys[1]
      end
      File.write file, INI.build data
    when "json"        then File.write file, del_json(JSON.parse(data), keys).to_pretty_json
    when "yml", "yaml" then File.write file, del_json(YAML.parse(data), keys.map { |str| YAML::Any.new str }).to_yaml
    else
      raise "not supported file format: " + format
    end
  end

  private def ini(data, k, v)
    case k.size
    when 1 then data[""][k[0]] = v
    when 2 then data[k[0]][k[1]] = v
    else
      raise "max key path exceeded: #{k.size}"
    end
    data
  end

  private def set_json(data, keys, val)
    first_key = keys.first
    if keys.size == 1
      data.as_h[first_key] = val
    else
      data.as_h[first_key] = set_json data[first_key], keys[1..-1], val
    end
    data
  end

  private def del_json(data, keys)
    first_key = keys.first
    if keys.size == 1
      data.as_h.delete first_key
    else
      data.as_h[first_key] = del_json data[first_key], keys[1..-1]
    end
    data
  end

  # The vars can't be modified
  struct Vars
    def initialize(pkgdir)
      @pkgdir = pkgdir
      @pkg = YAML.parse(File.read pkgdir + "/pkg.yml")["vars"][key]
    end

    def get(key)
      file = @pkg[key].as_h["self"]? ? @pkg[key]["self"].as_s.to_i : 0
      get @pkgdir + '/' + file, Utils.to_array(@pkg)
    end
  end

  struct Config
    @config : String
    @pkg : YAML::Any

    def initialize(pkgdir)
      file = Dir[pkgdir + "/etc/config.*"]
      raise "file not found: " + pkgdir + "/etc/config.*" if file.empty?
      @config = file[0]
      @pkg = YAML.parse(File.read pkgdir + "/pkg.yml")["config"]
    end

    def set(key : String, value)
      ConfFile.set @config, Utils.to_array(@pkg[key].as_s), value
    end

    def get(key : String)
      ConfFile.get @config, Utils.to_array(@pkg[key].as_s)
    end

    def del(key : String)
      ConfFile.get @config, Utils.to_array(@pkg[key].as_s)
    end
  end
end
