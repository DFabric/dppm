require "file_utils"
require "exec"
require "./logger"
require "./config"
require "./database"
require "./host"
require "./service"
require "./web_site"
require "./http_helper"

struct Prefix
  class_getter default_dppm_config = Config.new {{ read_file "./config.con" }}

  getter path : String,
    app : String,
    pkg : String,
    src : String

  def initialize(@path : String, check : Bool = false)
    @app = @path + "/app/"
    @pkg = @path + "/pkg/"
    @src = @path + "/src/"
    if check && !dppm.exists?
      raise "DPPM isn't installed in #{@path}. Run `dppm install`"
    end
  end

  def create
    Dir.mkdir @path
    Dir.mkdir @app
    Dir.mkdir @pkg
  end

  def dppm : App
    new_app "dppm"
  end

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

  def delete_src
    source_path = @src.rchop
    if File.symlink? source_path
      File.delete source_path
    else
      FileUtils.rm_rf @src
    end
  end

  # Download a cache of package sources
  def update(source : String? = dppm_config.source, force : Bool = false)
    source ||= dppm_config.source

    # Update cache if older than 2 days
    source_dir = @src.rchop
    packages_source_date = nil
    update = true
    if File.symlink?(source_dir)
      update = false
    elsif HTTPHelper.url? source
      if packages_source_date = HTTPHelper.get_string(source.gsub("tarball", "commits")).match(/(?<=datetime=").*T[0-9][0-9]:/).try &.[0]?
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
        Log.info "downloading packages source", source
        file = @path + '/' + File.basename source
        HTTPHelper.get_file source, file
        Host.exec "/bin/tar", {"zxf", file, "-C", @path}
        File.delete file
        File.rename Dir[@path + "/*packages-source*"][0], @src
        File.touch source_dir, Time.parse_utc(packages_source_date, "%Y-%m-%dT%H:")
        Log.info "cache updated", @src
      else
        FileUtils.mkdir_p @path
        File.symlink File.real_path(source), source_dir
        Log.info "symlink added from `#{File.real_path(source)}`", source_dir
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
