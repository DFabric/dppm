require "./pkg_file"

module Prefix::Base
  getter path : String
  getter name : String
  getter prefix : Prefix

  getter conf_dir : String do
    @path + "etc/"
  end

  getter pkg_file : PkgFile do
    PkgFile.new @path
  end

  getter config : Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML do
    if config_file = Dir[conf_dir + "config.*"][0]?
      Config.new config_file
    else
      raise "File not found: #{conf_dir}config.*"
    end
  end

  def get_config(key : String)
    config.get pkg_file.config[key]
  end
end
