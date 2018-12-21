require "./pkg_file"

module Prefix::Base
  getter path : String
  getter name : String
  getter prefix : Prefix

  @config : Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML | Nil = nil
  @conf : String? = nil
  @pkg_file : PkgFile?
  @pkg_file_config : Hash(String, String)? = nil

  def conf : String
    @conf ||= @path + "etc"
  end

  def pkg_file : PkgFile
    @pkg_file ||= PkgFile.new @path
  end

  def pkg_file_config : Hash(String, String)
    @pkg_file_config ||= if pkg_config = pkg_file.config
                           pkg_config
                         else
                           raise "not `config` key entry in " + pkg_file.path
                         end
  end

  def config : Config::CON | Config::INI | Config::JSON | Config::TOML | Config::YAML
    @config ||= if config_file = Dir[conf + "/config.*"][0]?
                  Config.new config_file
                else
                  raise "File not found: #{conf}/config.*"
                end
  end

  def get_config(key : String)
    config.get pkg_file_config[key]
  end
end
