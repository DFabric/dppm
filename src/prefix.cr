require "file_utils"
require "exec"
require "./dppm"
require "./logger"
require "./config"
require "./database"
require "./host"
require "./service"
require "./web_site"
require "./http_helper"

struct DPPM::Prefix
  # Default prefix for a DPPM installation.
  class_getter default : String do
    if (current_dir = Dir.current).ends_with? "app/dppm"
      Path[current_dir].parent.parent.parent.parent.parent.parent.to_s
    elsif File.exists? "/usr/local/bin/dppm"
      Path[File.real_path "/usr/local/bin/dppm"].parent.parent.parent.parent.parent.parent.to_s
    elsif Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end

  # Default DPPM configuration.
  class_getter default_dppm_config = Config.new {{ read_file "./config.con" }}

  # Default group namespace where installing applications.
  class_getter default_group : String = "default-group"

  # Default source name to get packages.
  class_getter default_source_name : String = "default"

  # Application group namespace used.
  getter group : String

  # Source name to use when building packages and creating applications.
  getter source_name : String

  # Path of the prefix on the filesystem.
  getter path : Path

  # Base path for applications.
  getter root_app : Path

  # Base path for packages.
  getter root_pkg : Path

  # Base path for packages sources.
  getter root_src : Path

  # Application path, including the `group` namespace.
  getter app : Path

  # Package path, including the `source_name`.
  getter pkg : Path

  # Package path, including the `source_name`.
  getter src : Path

  # Source path used, which can be an URL or a filesystem path.
  getter source_path : String do
    dppm_config.sources[@source_name]
  end

  def initialize(
    path : String,
    @group : String = @@default_group,
    @source_name : String = @@default_source_name,
    @source_path : String? = nil
  )
    @path = Path.new path
    @root_app = @path / "app"
    @root_pkg = @path / "pkg"
    @root_src = @path / "src"

    @app = @root_app / @group
    @pkg = @root_pkg / @source_name
    @src = @root_src / @source_name
  end

  # Create `@path` and all its subdirectories needed.
  def create
    {@path, @root_app, @root_pkg, @root_src, @app, @pkg}.each do |dir|
      Dir.mkdir dir.to_s if !Dir.exists? dir.to_s
    end
  end

  # Raises if DPPM isn't installated.
  def check
    raise "DPPM isn't installed in #{@path}. Run `dppm app install`" if !dppm.exists?
  end

  # Returns the DPPM application.
  def dppm : App
    new_app "dppm"
  end

  # DPPM configuration.
  property dppm_config : Config do
    if config_file = dppm.config_file
      Config.new File.read(config_file)
    else
      @@default_dppm_config
    end
  end

  def each_app(&block : App ->)
    Dir.each_child(@app.to_s) do |dir|
      yield App.new self, dir
    end
  end

  def each_pkg(&block : Pkg ->)
    Dir.each_child(@pkg.to_s) do |dir|
      yield Pkg.new self, dir
    end
  end

  def each_src(&block : Src ->)
    Dir.each_child(@src.to_s) do |dir|
      yield Src.new(self, dir) if dir[0].ascii_lowercase?
    end
  end

  # Creates a new `App` application object.
  def new_app(name : String) : App
    App.new self, name
  end

  # Creates a new `Pkg` package object.
  # A package name includes the package and optionally a version/tag separated by either a `_` or `:`.
  # If no version is provided, latest one will be used.
  def new_pkg(package_name : String, version : String? = nil, tag : String? = nil) : Pkg
    if version
      Pkg.new self, package_name, version
    else
      case package_name
      when .includes? '_'
        package, _, tag_or_version = package_name.partition '_'
      when .includes? ':'
        package, _, tag_or_version = package_name.partition ':'
      else
        package = package_name
      end
      src = Src.new self, package

      if tag_or_version && tag_or_version =~ /^[0-9]+\.[0-9]+(?:\.[0-9]+)?$/
        version = tag_or_version
      end
      if version
        src.pkg_file.ensure_version version
      else
        version = src.pkg_file.version_from_tag(tag || tag_or_version || "latest")
      end
      Pkg.new self, package, version, src.pkg_file, src
    end
  end

  # Creates a new `Src` source package object.
  def new_src(name : String) : Src
    Src.new self, name
  end

  # Delete the packages source `@src` directory.
  def delete_src
    if File.symlink? @src.to_s
      File.delete @src.to_s
    else
      FileUtils.rm_rf @src.to_s
    end
  end

  # Delete the prefix directory path.
  def delete
    delete_src
    FileUtils.rm_rf @path.to_s
  end

  # Download, or update a packages source cache.
  def update(force : Bool = false)
    packages_source_date = nil
    update = true
    if File.exists?(@src.to_s) && File.symlink?(@src.to_s)
      update = false
    elsif HTTPHelper.url? source_path
      if packages_source_date = HTTPHelper.get_string(source_path.gsub("tarball", "commits")).match(/(?<=datetime=").*T[0-9][0-9]:/).try &.[0]?
        if Dir.exists? @src.to_s
          update = !packages_source_date.starts_with? File.info(@src.to_s).modification_time.to_utc.to_s("%Y-%m-%dT%H:")
        else
          update = true
        end
      end
    else
      update = true
    end

    if force || update
      delete_src
      if packages_source_date
        Log.info "downloading packages source", source_path
        file = @root_src / File.basename(source_path)
        HTTPHelper.get_file source_path, file.to_s
        Host.exec "/bin/tar", {"zxf", file.to_s, "-C", @root_src.to_s}
        File.delete file
        File.rename Dir[(@root_src / "*packages-source*").to_s][0], @src.to_s
        File.touch @src.to_s, Time.parse_utc(packages_source_date, "%Y-%m-%dT%H:")
        Log.info "cache updated", @src.to_s
      else
        FileUtils.mkdir_p @root_src.to_s
        real_source_path = File.real_path source_path
        File.symlink real_source_path, @src.to_s
        Log.info "symlink added from `#{real_source_path}`", @src.to_s
      end
    else
      Log.info "cache up-to-date", @src.to_s
    end
  end

  def clean_unused_packages(confirmation : Bool = true, &block) : Set(String)
    packages = Set(String).new
    Log.info "retrieving available packages", @pkg.to_s
    each_pkg { |pkg| packages << pkg.name }

    Log.info "excluding used packages by applications", @pkg.to_s
    each_app do |app|
      packages.delete app.real_app_path.basename.to_s
      app.libs.each do |library|
        packages.delete library.name
      end
    end

    if packages.empty?
      Log.info "No packages to clean", @path.to_s
      return packages
    elsif confirmation
      Log.output << "task: clean"
      Log.output << "\nbasedir: " << @pkg
      Log.output << "\nunused packages: \n"
      packages.each do |pkg|
        Log.output << pkg << '\n'
      end
      return packages if !yield
    end

    Log.info "deleting packages", @pkg.to_s
    packages.each do |package|
      pkg = new_pkg package
      pkg.delete confirmation: false { }
      Log.info "package deleted", package
    end

    Log.info "packages cleaned", @pkg.to_s
    packages
  end
end

require "./prefix/*"
