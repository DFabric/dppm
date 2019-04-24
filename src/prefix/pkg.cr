require "./program_data"

class Prefix::Pkg
  include ProgramData

  getter package : String,
    version : String

  getter app_bin_path : String { @path + "app/bin" }

  protected property app_config_file : String? = nil, app_config : ::Config::Types? = nil

  protected def initialize(@prefix : Prefix, name : String, version : String? = nil, @pkg_file : PkgFile? = nil, @src : Src? = nil)
    if version
      @package, @version = name, version
    elsif name.includes? '_'
      @package, @version = name.split '_', limit: 2
    elsif name.includes? ':'
      @package, @version = name.split ':', limit: 2
    else
      raise "no version provided for #{name}"
    end
    @name = @package + '_' + @version

    @path = @prefix.pkg + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
    @bin_path = @path + "bin"
  end

  def self.create(prefix : Prefix, name : String, version : String?, tag : String?)
    if name.includes? '_'
      package, tag_or_version = name.split '_', limit: 2
    elsif name.includes? ':'
      package, tag_or_version = name.split ':', limit: 2
    else
      package = name
    end
    src = Src.new prefix, package

    if tag_or_version && tag_or_version =~ /^[0-9]+\.[0-9]+(?:\.[0-9]+)?$/
      version = tag_or_version
    end
    if version
      # Check if the version number is available
      available_version = false
      src.pkg_file.each_version do |ver|
        if version == ver
          available_version = true
          break
        end
      end
      raise "no available version number: " + version if !available_version
    else
      version = src.pkg_file.version_from_tag(tag || tag_or_version || "latest")
    end
    new prefix, package, version, src.pkg_file, src
  rescue ex
    raise Exception.new "can't obtain a version:\n#{ex}", ex
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
    App.new @prefix, app_name, self
  end

  def src : Src
    @src ||= Src.new @prefix, @package, @pkg_file
  end

  # Copy the source to this package directory path
  def copy_src_to_path
    FileUtils.cp_r src.path, @path
  end

  def get_config(key : String)
    config_from_pkg_file key do |package_config, config_key|
      return package_config.get config_key
    end
    deps_with_expr.each_key &.config_from_pkg_file key do |package_config, config_key|
      return package_config.get config_key
    end
    raise "config key not found: " + key
  end

  def each_config_key(&block : String ->)
    internal_each_config_key { |key| yield key }
    deps_with_expr.each_key &.internal_each_config_key { |key| yield key }
  end

  def each_binary_with_path(&block : String, String ->)
    {@bin_path, app_bin_path}.each do |path|
      if Dir.exists? path
        Dir.each_child path do |binary|
          yield path, binary
        end
      end
    end
  end

  # Create symlinks to a globally reachable path
  def create_global_bin_symlinks(force : Bool = false)
    each_binary_with_path do |path, binary|
      global_bin = "/usr/local/bin/" + binary
      File.delete global_bin if File.exists? global_bin
      File.symlink path + '/' + binary, global_bin
    end
  end

  def delete_global_bin_symlinks
    each_binary_with_path do |path, binary|
      global_bin = "/usr/local/bin/" + binary
      if File.exists?(global_bin) && File.real_path(global_bin) == path + '/' + binary
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
    vars["prefix"] = @prefix.path
    vars["version"] = @version
    vars["package"] = @package
    vars["basedir"] = @path
    vars["arch_alias"] = arch_alias
    if env = pkg_file.env
      vars.merge! env
    end

    if File.exists? @path
      Log.info "already present", @path
      return self if confirmation
      yield
      return self
    else
      simulate vars, deps, "build", confirmation, Log.output, &block
    end

    begin
      if File.exists? @path
        Log.info "package already present", @path
        return self
      end
      copy_src_to_path

      # Build dependencies
      install_deps(deps) { }
      if (tasks = pkg_file.tasks) && (build_task = tasks["build"]?)
        Log.info "building", @name
        Dir.cd(@path) { Task.new(vars.dup, all_bin_paths).run build_task }
      else
        raise "missing tasks.build key in " + pkg_file.path
      end
      FileUtils.rm_rf libs_dir.rchop
      @libs = @all_bin_paths = nil

      Log.info "build completed", @path
      self
    rescue ex
      begin
        delete false { }
      ensure
        raise Exception.new "build failed - package deleted: #{@path}:\n#{ex}", ex
      end
    end
  end

  private def move(path : String)
    Dir.each_child(path) do |entry|
      src = path + entry
      dest = '.' + src
      if Dir.exists? dest
        move src + '/'
      else
        File.rename src, dest
      end
    end
  end

  def delete(confirmation : Bool = true, &block) : Pkg?
    raise "package doesn't exist: " + @path if !File.exists? @path

    # Check if the package is still in use by an application
    Log.info "check packages in use", @path
    prefix.each_app do |app|
      if app.real_app_path + '/' == @path
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
    FileUtils.rm_rf @path
    Log.info "package deleted", @path
    self
  end
end
