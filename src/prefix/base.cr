require "./pkg_file"
require "semantic_compare"

module Prefix::Base
  getter path : String
  getter name : String
  getter prefix : Prefix

  getter libs_dir : String do
    @path + "lib/"
  end

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
      if config_vars = pkg_file.config.vars
        if config_key = config_vars[key]?
          yield config, config_key
        end
      end
    end
  end

  abstract def each_config_key(&block : String ->)

  protected def internal_each_config_key(&block : String ->)
    pkg_file.config.vars.try &.each_key do |var|
      yield var
    end
  end

  getter deps_with_expr : Hash(Prefix::Src, String) do
    deps = Hash(Prefix::Src, String).new
    pkg_file.deps.try &.each do |name, version|
      deps[prefix.new_src name] = version
    end
    deps
  end

  def resolve_deps(dependencies : Hash(String, Array(SemanticVersion)) = Hash(String, Array(SemanticVersion)).new) : Hash(String, Array(SemanticVersion))
    # No need to parse if the deps list is empty
    deps_with_expr.each do |dep_src, version_expr|
      if !File.exists? libs_dir + dep_src.name
        Log.info "calculing dependency", dep_src.name
        newvers = Array(SemanticVersion).new

        # If an array of versions is already provided by a dependency
        if dep_vers = dependencies[dep_src.name]?
          dep_vers.each do |semantic_version|
            newvers << semantic_version if SemanticCompare.expression semantic_version, version_expr
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          dependencies[dep_src.name] = Array(SemanticVersion).new
          dep_src.pkg_file.each_version do |ver|
            semantic_version = SemanticVersion.parse ver
            newvers << semantic_version if SemanticCompare.expression semantic_version, version_expr
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{dep_src.pkg_file.package}`: no versions match `#{version_expr}`" if !newvers[0]?
        dependencies[dep_src.name] = newvers

        # Loops inside dependencies of dependencies
        dependencies = dep_src.resolve_deps(dependencies) if dep_src.pkg_file.deps
      end
    end
    dependencies
  end
end
