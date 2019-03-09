require "./pkg_file"
require "semantic_compare"

module Prefix::Base
  getter path : String,
    name : String,
    prefix : Prefix

  getter libs_dir : String { @path + "libs/" }
  getter conf_dir : String { @path + "conf/" }
  getter pkg_file : PkgFile { PkgFile.new @path }

  @config_file_initialized = false

  getter config_file : File? do
    if !@config_file_initialized
      if Dir.exists? conf_dir.rchop
        Dir.each_child conf_dir do |file|
          file_path = conf_dir + file
          if file.starts_with? "config."
            @config_file = File.new file_path
          end
        end
      end
      @config_file_initialized = true
    end
    @config_file
  end

  def config_file!
    config_file || raise "config file not available"
  end

  @config_initialized = false

  getter config : ::Config::Types? do
    if !@config_initialized && config_file
      @config = ::Config.new? config_file!
      @config_initialized = true
    end
    @config
  end

  def config! : ::Config::Types
    config || raise "no valid config file: #{conf_dir}config.*"
  end

  abstract def get_config(key : String)

  protected def config_from_pkg_file(key : String, &block)
    config.try do |config|
      if config_vars = pkg_file.config_vars
        if config_key = config_vars[key]?
          yield config, config_key
        end
      end
    end
  end

  abstract def each_config_key(&block : String ->)

  protected def internal_each_config_key(&block : String ->)
    pkg_file.config_vars.try &.each_key do |var|
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

  def resolve_deps(dependencies : Hash(String, Set(SemanticVersion)) = Hash(String, Set(SemanticVersion)).new) : Hash(String, Set(SemanticVersion))
    # No need to parse if the deps list is empty
    deps_with_expr.each do |dep_src, version_expr|
      if !File.exists? libs_dir + dep_src.name
        Log.info "calculing dependency", dep_src.name
        newvers = Set(SemanticVersion).new

        # If an array of versions is already provided by a dependency
        if dep_vers = dependencies[dep_src.name]?
          dep_vers.each do |semantic_version|
            newvers << semantic_version if SemanticCompare.expression semantic_version, version_expr
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          dependencies[dep_src.name] = Set(SemanticVersion).new
          dep_src.pkg_file.each_version do |ver|
            semantic_version = SemanticVersion.parse ver
            newvers << semantic_version if SemanticCompare.expression semantic_version, version_expr
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{dep_src.pkg_file.package}`: no versions match `#{version_expr}`" if !newvers.first?
        dependencies[dep_src.name] = newvers

        # Loops inside dependencies of dependencies
        dependencies = dep_src.resolve_deps(dependencies) if dep_src.pkg_file.deps
      end
    end
    dependencies
  end

  def finalize
    @config_file.try &.close
  end
end
