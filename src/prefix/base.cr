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

  @config : Config::Types?
  @config_initialized = false

  def config! : Config::Types
    config || raise "no valid config file: #{conf_dir}config.*"
  end

  def config : Config::Types?
    if !@config_initialized
      if Dir.exists? conf_dir.rchop
        Dir.each_child conf_dir do |file|
          file_path = conf_dir + file
          if file.starts_with? "config."
            @config = Config.new? file_path
          end
        end
      end
      @config_initialized = true
    end
    @config
  end

  abstract def get_config(key : String)

  protected def config_from_pkg_file(key : String, &block)
    config.try do |config|
      if config_key = pkg_file.config[key]?
        yield config, config_key
      end
    end
  end

  abstract def each_config_key(&block : String ->)

  protected def internal_each_config_key(&block : String ->)
    pkg_file.config?.try &.each_key do |var|
      yield var
    end
  end

  getter deps : Array(Prefix::Src) do
    deps = Array(Prefix::Src).new
    pkg_file.deps.try &.each do |name, version|
      deps << @prefix.new_src name
    end
    deps
  end
end
