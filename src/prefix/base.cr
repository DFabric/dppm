require "./pkg_file"

module Prefix::Base
  getter path : String
  getter name : String
  getter prefix : Prefix

  @config : Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML | Nil = nil
  @conf_dir : String? = nil
  @pkg_file : PkgFile?

  def conf_dir : String
    @conf_dir ||= @path + "etc/"
  end

  def pkg_file : PkgFile
    @pkg_file ||= PkgFile.new @path
  end

  def config : Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML
    @config ||= if config_file = Dir[conf_dir + "config.*"][0]?
                  Config.new config_file
                else
                  raise "File not found: #{conf_dir}config.*"
                end
  end

  def get_config(key : String)
    config.get pkg_file.config[key]
  end
end
