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

struct Prefix
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

  def new_app(name : String) : App
    App.new self, name
  end

  def new_pkg(name : String, version : String? = nil) : Pkg
    Pkg.new self, name, version
  end

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

  def clean_unused_packages(confirmation : Bool = true, &block) : Set(String)?
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
      return
    elsif confirmation
      Log.output << "task: clean"
      Log.output << "\nbasedir: " << @pkg
      Log.output << "\nunused packages: \n"
      packages.each do |pkg|
        Log.output << pkg << '\n'
      end
      return if !yield
    end

    Log.info "deleting packages", @pkg.to_s
    packages.each do |package|
      pkg_prefix = new_pkg package
      FileUtils.rm_rf pkg_prefix.path.to_s
      Log.info "package deleted", package
    end

    Log.info "packages cleaned", @pkg.to_s
    packages
  end
end

require "./prefix/*"
