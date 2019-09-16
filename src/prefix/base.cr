require "./pkg_file"
require "semantic_compare"

module DPPM::Prefix::Base
  # Root path of the package.
  getter path : Path

  # Name of the package.
  getter name : String

  # Prefix used.
  getter prefix : Prefix

  getter libs_path : Path { @path / "libs/" }
  getter conf_path : Path { @path / "conf" }
  getter pkg_file : PkgFile { PkgFile.new @path }

  @config_file_initialized = false

  # Raises if the configuration file if it exists.
  getter? config_file : Path? do
    if !@config_file_initialized
      if Dir.exists? conf_path.to_s
        Dir.each_child conf_path.to_s do |file|
          if file.starts_with? "config."
            @config_file = conf_path / file
          end
        end
      end
      @config_file_initialized = true
    end
    @config_file
  end

  # Raises if the configuration file doesn't exist.
  def config_file! : Path
    config_file? || raise "Config file not available"
  end

  @config_initialized = false

  # Returns the main configuration.
  getter? config : ::Config::Types? do
    if !@config_initialized && config_file?
      @config = ::Config.read? config_file!
      @config_initialized = true
    end
    @config
  end

  # Raises if no configuration is available.
  def config! : ::Config::Types
    config? || raise "No valid config file: #{conf_path}config.*"
  end

  class ConfigKeyError < Exception
  end

  private def config_key_exception(key : String)
    raise ConfigKeyError.new "Missing config key: " + key.inspect
  end

  # Gets the config key. Raises a `ConfigKeyError` if the key is not found.
  def get_config(key : String)
    get_config(key) { config_key_exception key }
  end

  # Gets the config key, if any.
  def get_config?(key : String)
    get_config(key) { nil }
  end

  abstract def get_config(key : String, &block)

  protected def config_from_pkg_file(key : String, &block)
    if app_config = config?
      if config_vars = pkg_file.config_vars
        if config_key = config_vars[key]?
          yield app_config, config_key
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

  # `Hash` of each source with its version expression to match.
  getter deps_with_expr : Hash(Prefix::Src, String) do
    deps = Hash(Prefix::Src, String).new
    pkg_file.deps.try &.each do |name, version|
      deps[prefix.new_src name] = version
    end
    deps
  end

  # Resolves semver expressions recursively.
  def resolve_deps(dependencies : Hash(String, Array(SemanticVersion)) = Hash(String, Array(SemanticVersion)).new) : Hash(String, Array(SemanticVersion))
    deps_with_expr.each do |dep_src, version_expr|
      if !File.exists? (libs_path / dep_src.name).to_s
        Log.info "calculating dependency", dep_src.name

        # If an array of versions is already provided by a dependency
        if dep_vers = dependencies[dep_src.name]?
          dep_vers.select! do |semantic_version|
            SemanticCompare.expression semantic_version, version_expr
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          dep_vers = dependencies[dep_src.name] = Array(SemanticVersion).new
          dep_src.pkg_file.each_version do |ver|
            semantic_version = SemanticVersion.parse ver
            dep_vers << semantic_version if SemanticCompare.expression semantic_version, version_expr
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "Dependency error for `#{dep_src.pkg_file.package}`: no versions match `#{version_expr}`" if dep_vers.empty?

        # Loops inside dependencies of dependencies
        dependencies = dep_src.resolve_deps(dependencies) if dep_src.pkg_file.deps
      end
    end
    dependencies
  end

  private def import_pkg_file(foreign_pkg_file : PkgFile) : PkgFile
    foreign_pkg_file.path = nil
    foreign_pkg_file.root_path = @path
    @pkg_file = foreign_pkg_file
  end
end
