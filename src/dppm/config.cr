require "ini"
require "dynany/json"
require "dynany/yaml"

module ConfFile
  extend self

  def get(file, path : Array, format = File.extname(file).lchop)
    data = File.read file
    data = case format.empty? ? File.extname(file) : format
           when "ini", "INI", "toml"
             data = INI.parse data
             case path.size
             when 1 then data[path[0].to_s]?
             when 2
               if ini = data[path[0].to_s]?
                 ini[path[1].to_s]?
               end
             else
               raise "max key path exceeded: #{path.size}"
             end
           when "json"        then JSON.parse(data)[path]?
           when "yml", "yaml" then YAML.parse(data)[path]?
           else
             raise "not supported file format: " + format
           end
  end

  def get(file, path : String, format = File.extname(file).lchop)
    get file, Utils.to_array(path), format
  end

  def set(file, path : Array, value, format = File.extname(file).lchop)
    data = File.read file
    case format.empty? ? File.extname(file) : format
    when "ini", "INI", "toml"
      space = data.includes?(" = ") ? true : false
      data = INI.parse data
      case path.size
      when 1 then data[""][path[0].to_s] = value.to_s
      when 2 then data[path[0].to_s][path[1].to_s] = value.to_s
      else
        raise "max key path exceeded: #{path.size}"
      end
      data = INI.build data, space
    when "json"
      json = JSON.parse data
      value = Utils.to_type value
      json[path] = JSON::Any.new case value
      when .is_a? Hash(String, String) then Hash(String, JSON::Any).new
      when .is_a? Array(String)        then Array(JSON::Any).new
      else
        value
      end
      data = json.to_pretty_json
    when "yml", "yaml"
      yaml = YAML.parse data
      value = Utils.to_type value
      yaml[path] = YAML::Any.new case value
      when .is_a? Hash(String, String) then Hash(YAML::Any, YAML::Any).new
      when .is_a? Array(String)        then Array(YAML::Any).new
      else
        value
      end
      data = yaml.to_yaml
    else
      raise "not supported file format: " + format
    end
    File.write file, data
  end

  def set(file, path : String, value, format = File.extname(file).lchop)
    set file, Utils.to_array(path), value, format
  end

  def del(file, path : Array, format = File.extname(file).lchop)
    data = File.read file

    case format
    when "ini", "INI", "toml"
      data = INI.parse data
      case path.size
      when 1 then data.delete path[0].to_s
      when 2 then data[path[0].to_s].delete path[1].to_s
      end
      data = INI.build data
    when "json"        then data = JSON.parse(file).delete(path).to_pretty_json
    when "yml", "yaml" then data = YAML.parse(file).delete(path).to_yaml
    else
      raise "not supported file format: " + format
    end
    File.write file, data
  end

  def del(file, path : String, format = File.extname(file).lchop)
    del file, Utils.to_array(path), format
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

  module CLI
    extend self

    def get(prefix, nopkg : Bool, application, path)
      config = Config.new ::Package::Path.new(prefix).app + '/' + application
      if nopkg
        return File.read(config.file) if path == "."
        ConfFile.get config.file, path
      elsif path == "."
        String.build do |str|
          config.pkg.as_h.each_key do |key|
            str << key << ": " << config.get(key.as_s) << '\n'
          end
        end
      else
        config.get path
      end
    end

    def set(prefix, nopkg : Bool, application, path, value)
      config = Config.new ::Package::Path.new(prefix).app + '/' + application
      if nopkg
        ConfFile.set config.file, path, value
      else
        config.set path, value
      end
    end

    def del(prefix, nopkg : Bool, application, path)
      config = Config.new ::Package::Path.new(prefix).app + '/' + application
      if nopkg
        ConfFile.del config.file, path
      else
        config.del path
      end
    end
  end

  struct Config
    getter file : String
    getter pkg : YAML::Any

    def initialize(pkgdir)
      file = Dir[pkgdir + "/etc/config.*"]
      raise "file not found: #{pkgdir}/etc/config.*" if file.empty?
      @file = file.first
      @pkg = YAML.parse(File.read pkgdir + "/pkg.yml")["config"]
    end

    def set(key : String, value)
      ConfFile.set @file, @pkg[key].as_s, value
    end

    def get(key : String)
      ConfFile.get @file, @pkg[key].as_s
    end

    def del(key : String)
      ConfFile.del @file, @pkg[key].as_s
    end
  end
end
