require "ini"
require "json"
require "yaml"

module ConfFile
  extend self

  def get(file, keys : Array, config = "")
    data = File.read file
    data = case config.empty? ? file.split('.')[-1] : config
           when "ini", "INI"  then INI.parse data
           when "json"        then JSON.parse data
           when "yml", "yaml" then YAML.parse data
           else
             raise "not supported file format: " + file
           end
    keys.each do |key|
      return unless data = data[key]?
    end
    data
  end

  def set(file, keys : Array, value, config = "")
    data = File.read file
    case config.empty? ? file.split('.')[-1] : config
    when "ini", "INI"
      space = data.includes?(" = ") ? true : false
      File.write file, INI.build(ini(INI.parse(data), keys, value), space)
    when "json"
      val = Utils.to_type value
      case val
      when .is_a? Hash(String, String) then val = Hash(String, JSON::Type).new
      when .is_a? Array(String)        then val = Array(JSON::Type).new
      end

      File.write file, json(JSON.parse(data), keys, val).to_pretty_json
    when "yml", "yaml"
      val = Utils.to_type value
      case val
      when .is_a? Hash(String, String) then val = Hash(YAML::Type, YAML::Type).new
      when .is_a? Array(String)        then val = Array(YAML::Type).new
      end

      File.write file, json(YAML.parse(data), keys, val).to_yaml
    else
      raise "not supported file format: " + file
    end
  end

  def del(file, keys : Array, config = "")
    data = File.read file

    conf = config.empty? ? File.extname(file) : config
    File.write file, case conf
    when "ini", "INI"
      data = INI.parse data
      case keys.size
      when 1 then data.delete keys[0]
      when 2 then data[keys[0]].to_h.delete keys[1]
      end
      INI.build data
    when "json"        then del_json(JSON.parse(data), keys).to_pretty_json
    when "yml", "yaml" then del_json(YAML.parse(data), keys).to_yaml
    end
  end

  private def del_json(data, k)
    case k.size
    when 1 then data.as_h.delete k[0]
    when 2 then data[k[0]].as_h.delete k[1]
    when 3 then data[k[0]][k[1]].as_h.delete k[2]
    when 4 then data[k[0]][k[1]][k[2]].as_h.delete k[3]
    else
      raise "max key path exceeded: #{k.size}"
    end
    data
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

  private def json(data, k, val)
    # Change the value of the specified key
    # Not found a better way to do it yet
    case k.size
    when 1 then data.as_h[k[0]] = val
    when 2 then data[k[0]].as_h[k[1]] = val
    when 3 then data[k[0]][k[1]].as_h[k[2]] = val
    when 4 then data[k[0]][k[1]][k[2]].as_h[k[3]] = val
    when 5 then data[k[0]][k[1]][k[2]][k[3]].as_h[k[4]] = val
    when 6 then data[k[0]][k[1]][k[2]][k[3]][k[4]].as_h[k[5]] = val
    when 7 then data[k[0]][k[1]][k[2]][k[3]][k[4]][k[5]].as_h[k[6]] = val
    else
      raise "max key path exceeded: #{k.size}"
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
      file = @pkg[key].as_h.has_key?("self") ? @pkg[key]["self"].as_s.to_i : 0
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
