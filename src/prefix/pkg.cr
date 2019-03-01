require "./program_data"

struct Prefix::Pkg
  include ProgramData
  getter package : String,
    version : String

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

    if !version && !tag
      if tag_or_version
        if tag_or_version =~ /^([0-9]+\.[0-9]+\.[0-9]+)/
          version = tag_or_version
        else
          tag = tag_or_version
        end
      else
        # Set a default tag if not set
        tag = "latest"
      end
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
      raise "not available version number: " + version if !available_version
    elsif tag
      version = src.pkg_file.version_from_tag tag
    else
      raise "fail to get a version"
    end
    new prefix, package, version, src.pkg_file, src
  rescue ex
    raise Exception.new "can't obtain a version:\n#{ex}", ex
  end

  def new_app(app_name : String? = nil) : App
    case pkg_file.type
    when .app?
      # Generate a name if none is set
      app_name ||= package + '-' + Random::Secure.hex(8)
      Utils.ascii_alphanumeric_dash? app_name
    else
      # lib and others
      raise "only applications can be added to the system: #{pkg_file.type}"
    end
    App.new @prefix, app_name, self
  end

  def src : Src
    @src ||= Src.new @prefix, @package, @pkg_file
  end

  def get_config(key : String)
    config_from_pkg_file key do |config_file, config_key|
      return config_file.get config_key
    end
    deps_with_expr.each_key &.config_from_pkg_file key do |config_file, config_key|
      return config_file.get config_key
    end
    raise "config key not found: " + key
  end

  def each_config_key(&block : String ->)
    internal_each_config_key { |key| yield key }
    deps_with_expr.each_key &.internal_each_config_key { |key| yield key }
  end

  # Used to install dependencies, avoiding recursive block expansions
  def build(mirror : String)
    build mirror: mirror, confirmation: false { }
  end

  # Build the package. Yields a block before writing on disk. When confirmation is set, the block must be true to continue.
  def build(deps : Set(Pkg) = Set(Pkg).new, mirror : String? = nil, confirmation : Bool = true, &block)
    mirror ||= Prefix::Config.mirror
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
                  versions[0].to_s
                end
      deps << dep_src.new_pkg dep_name, version
    end
    vars["prefix"] = @prefix.path
    vars["version"] = @version
    vars["package"] = @package
    vars["basedir"] = @path
    vars["arch_alias"] = arch_alias
    vars["mirror"] = mirror
    if env = pkg_file.env
      vars.merge! env
    end

    if File.exists? @path
      Log.info "already present", @path
      return self if confirmation
      yield
      return self
    elsif confirmation
      Log.output << "task: build"
      vars.each do |var, value|
        Log.output << '\n' << var << ": " << value
      end
      simulate_deps deps, Log.output
      return if !yield
    else
      yield
    end

    if File.exists? @path
      Log.info "package already present", @path
      return self
    end

    # Copy the sources to the @pkg.name directory to build
    FileUtils.cp_r src.path, @path

    # Build dependencies
    install_deps(deps, mirror) { }
    if (tasks = pkg_file.tasks) && (build_task = tasks["build"]?)
      Log.info "building", @name
      Dir.cd(@path) { Task.new(vars.dup, all_bin_paths).run build_task }
      # Standard package build
    else
      Log.info "standard building", @name

      working_directory = if pkg_file.type.app?
                            Dir.mkdir app_path
                            app_path
                          else
                            @path
                          end
      Dir.cd working_directory do
        package_full_name = "#{@package}-static_#{@version}_#{Host.kernel}_#{Host.arch}"
        package_archive = package_full_name + ".tar.xz"
        package_mirror = mirror + '/' + package_archive
        Log.info "downloading", package_mirror
        HTTPHelper.get_file package_mirror
        Log.info "extracting", package_mirror
        Host.exec "/bin/tar", {"Jxf", package_archive}

        # Move out files from the archive folder
        Dir.cd package_full_name do
          move "./"
        end
        FileUtils.rm_r({package_archive, package_full_name})
      end
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
        if @path == library.pkg.path
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

    FileUtils.rm_rf @path
    Log.info "package deleted", @path
    self
  end
end
