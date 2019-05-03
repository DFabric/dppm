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
  getter path : String

  # Base path for applications.
  getter root_app : String

  # Base path for packages.
  getter root_pkg : String

  # Base path for packages sources.
  getter root_src : String

  # Application path, including the group namespace.
  getter app : String

  # Package path, including the source.
  getter pkg : String

  # Package path, including the source.
  getter src : String

  # Source path used, which can be an URL or a filesystem path.
  getter source_path : String do
    dppm_config.sources[@source_name]
  end

  def initialize(
    @path : String,
    @group : String = @@default_group,
    @source_name : String = @@default_source_name,
    @source_path : String? = nil
  )
    @root_app = @path + "/app/"
    @root_pkg = @path + "/pkg/"
    @root_src = @path + "/src/"

    @app = @root_app + @group + '/'
    @pkg = @root_pkg + @source_name + '/'
    @src = @root_src + @source_name + '/'
  end

  # Create `@path` and all its subdirectories needed.
  def create
    {@path, @root_app, @root_pkg, @root_src, @app, @pkg}.each do |dir|
      Dir.mkdir dir if !Dir.exists? dir
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
      Config.new config_file.gets_to_end
    else
      @@default_dppm_config
    end
  end

  def each_app(&block : App ->)
    Dir.each_child(@app) do |dir|
      yield App.new self, dir
    end
  end

  def each_pkg(&block : Pkg ->)
    Dir.each_child(@pkg) do |dir|
      yield Pkg.new self, dir
    end
  end

  def each_src(&block : Src ->)
    Dir.each_child(@src) do |dir|
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
    source_path = @src.rchop
    if File.symlink? source_path
      File.delete source_path
    else
      FileUtils.rm_rf src
    end
  end

  # Download, or update a packages source cache.
  def update(force : Bool = false)
    source_dir = src.rchop
    packages_source_date = nil
    update = true
    if File.exists?(source_dir) && File.symlink?(source_dir)
      update = false
    elsif HTTPHelper.url? source_path
      if packages_source_date = HTTPHelper.get_string(source_path.gsub("tarball", "commits")).match(/(?<=datetime=").*T[0-9][0-9]:/).try &.[0]?
        if Dir.exists? @src
          update = !packages_source_date.starts_with? File.info(@src.rchop).modification_time.to_utc.to_s("%Y-%m-%dT%H:")
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
        file = @root_src + '/' + File.basename source_path
        HTTPHelper.get_file source_path, file
        Host.exec "/bin/tar", {"zxf", file, "-C", @root_src}
        File.delete file
        File.rename Dir[@root_src + "/*packages-source*"][0], @src
        File.touch source_dir, Time.parse_utc(packages_source_date, "%Y-%m-%dT%H:")
        Log.info "cache updated", @src
      else
        FileUtils.mkdir_p @root_src
        real_source_path = File.real_path source_path
        File.symlink real_source_path, source_dir
        Log.info "symlink added from `#{real_source_path}`", source_dir
      end
    else
      Log.info "cache up-to-date", @src
    end
  end

  def clean_unused_packages(confirmation : Bool = true, &block) : Set(String)?
    packages = Set(String).new
    Log.info "retrieving available packages", @pkg
    each_pkg { |pkg| packages << pkg.name }

    Log.info "excluding used packages by applications", @pkg
    each_app do |app|
      packages.delete File.basename(app.real_app_path)
      app.libs.each do |library|
        packages.delete library.name
      end
    end

    if packages.empty?
      Log.info "No packages to clean", @path
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

    Log.info "deleting packages", @pkg
    packages.each do |pkg|
      pkg_prefix = new_pkg pkg
      FileUtils.rm_rf pkg_prefix.path
      Log.info "package deleted", pkg
    end

    Log.info "packages cleaned", @pkg
    packages
  end
end

require "./prefix/*"
