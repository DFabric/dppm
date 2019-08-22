require "./program_data"
require "semantic_version"

class DPPM::Prefix::Pkg
  include ProgramData

  # Package name.
  getter package : String

  # Version of the package.
  getter version : String

  # Semantic version representation.
  getter semantic_version : SemanticVersion { SemanticVersion.parse @version }

  # Path of the application binary.
  getter bin_path : Path

  protected property app_config_file : Path? = nil, app_config : ::Config::Types? = nil

  protected def initialize(@prefix : Prefix, name : String, version : String? = nil, pkg_file : PkgFile? = nil, @src : Src? = nil)
    if version
      @package, @version = name, version
    elsif name.includes? '_'
      @package, _, @version = name.partition '_'
    else
      raise "no version provided for #{name}"
    end
    @name = @package + '_' + @version

    @path = @prefix.pkg / @name
    if pkg_file
      import_pkg_file pkg_file
    end

    @bin_path = @path / "bin"
  end

  def new_app(app_name : String? = nil) : App
    case pkg_file.type
    when .lib?
      raise "only applications can be added to the system: #{pkg_file.type}"
    else
      # Generate a name if none is set
      app_name ||= package + '-' + Random::Secure.hex(8)
      Utils.ascii_alphanumeric_dash? app_name
    end
    App.new @prefix, app_name, pkg_file, self
  end

  def src : Src
    @src ||= Src.new @prefix, @package, @pkg_file
  end

  # Copy the source to this package directory path
  def copy_src_to_path
    FileUtils.cp_r src.path.to_s, @path.to_s
  end

  # Gets the config key. Yields the block if not found.
  def get_config(key : String, &block)
    config_from_pkg_file key do |package_config, config_key|
      return package_config.get config_key
    end
    deps_with_expr.each_key &.config_from_pkg_file key do |package_config, config_key|
      return package_config.get config_key
    end
    yield
  end

  def each_config_key(&block : String ->)
    internal_each_config_key { |key| yield key }
    deps_with_expr.each_key &.internal_each_config_key { |key| yield key }
  end

  def each_binary_with_path(&block : Path, String ->)
    {@bin_path, app_bin_path}.each do |path|
      if Dir.exists? path.to_s
        Dir.each_child path.to_s do |binary|
          yield path, binary
        end
      end
    end
  end

  # Create symlinks to a globally reachable path
  def create_global_bin_symlinks(force : Bool = false)
    each_binary_with_path do |path, binary|
      global_bin = Path["/usr/local/bin", binary].to_s
      File.delete global_bin if File.exists? global_bin
      File.symlink (path / binary).to_s, global_bin
    end
  end

  def delete_global_bin_symlinks
    each_binary_with_path do |path, binary|
      global_bin = Path["/usr/local/bin", binary].to_s
      if File.exists?(global_bin) && File.real_path(global_bin) == (path / binary).to_s
        File.delete global_bin
      end
    end
  end

  # Used to install dependencies, avoiding recursive block expansions
  def build
    build confirmation: false { }
  end

  # Build the package. Yields a block before writing on disk. When confirmation is set, the block must be true to continue.
  def build(deps : Set(Pkg) = Set(Pkg).new, confirmation : Bool = true, &block)
    if !@pkg_file
      import_pkg_file src.pkg_file
    end
    pkg_file.ensure_version @version

    vars = Host.vars.dup
    arch_alias = if (aliases = pkg_file.aliases) && (version_alias = aliases[Host.arch]?)
                   version_alias
                 else
                   Host.arch
                 end

    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @name
    src.resolve_deps.each do |dep_name, versions|
      dep_src = @prefix.new_src(dep_name)
      version = if versions.includes?(latest = dep_src.pkg_file.version_from_tag "latest")
                  latest
                else
                  versions.first.to_s
                end
      deps << dep_src.new_pkg dep_name, version
    end
    vars["prefix"] = @prefix.path.to_s
    vars["version"] = @version
    vars["package"] = @package
    vars["basedir"] = @path.to_s
    vars["arch_alias"] = arch_alias
    if env = pkg_file.env
      vars.merge! env
    end

    if exists?
      Log.info "already present", @path.to_s
      return self if confirmation
      yield
      return self
    else
      simulate vars, deps, "build", confirmation, Log.output, &block
    end

    begin
      if exists?
        Log.info "package already present", @path.to_s
        return self
      end
      @prefix.ensure_pkg_dir
      copy_src_to_path

      # Build dependencies
      install_deps(deps) { }
      if (tasks = pkg_file.tasks) && (build_task = tasks["build"]?)
        Log.info "building", @name
        Dir.cd(@path.to_s) { Task.new(vars.dup, all_bin_paths).run build_task }
      else
        raise "missing tasks.build key in " + pkg_file.path.to_s
      end
      FileUtils.rm_rf libs_path.to_s
      @libs = @all_bin_paths = nil

      Log.info "build completed", @path.to_s
      self
    rescue ex
      begin
        delete false { }
      ensure
        raise Exception.new "build failed - package deleted: #{@path}", ex
      end
    end
  end

  private def move(path : Path)
    Dir.each_child(path.to_s) do |entry|
      src = path / entry
      if Dir.exists? src.to_s
        move src
      else
        File.rename src.to_s, dest.to_s
      end
    end
  end

  def delete(confirmation : Bool = true, &block) : Pkg?
    raise "package doesn't exist: " + @path.to_s if !File.exists? @path.to_s

    # Check if the package is still in use by an application
    Log.info "check packages in use", @path.to_s
    prefix.each_app do |app|
      if @path == app.real_app_path
        raise "application package `#{package}` still in use by an application: " + app.name
      end
      app.libs.each do |library|
        if @path == library.path
          raise "library package `#{package}` still in use by an application: " + app.name
        end
      end
    end

    if confirmation
      Log.output << "task: delete"
      Log.output << "\npackage: " << @package
      Log.output << "\nversion: " << @version
      Log.output << "\nbasedir: " << @path
      Log.output << '\n'
      return if !yield
    end

    delete_global_bin_symlinks if Process.root?
    FileUtils.rm_rf @path.to_s
    Log.info "package deleted", @path.to_s
    self
  end
end
