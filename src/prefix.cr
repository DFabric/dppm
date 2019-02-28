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
  DEFAULT_PATH = begin
    if Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end

  getter path : String,
    app : String,
    pkg : String,
    src : String

  def initialize(@path : String = DEFAULT_PATH, create : Bool = false)
    @app = @path + "/app/"
    @pkg = @path + "/pkg/"
    @src = @path + "/src/"
    FileUtils.mkdir_p({@app, @pkg}) if create
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

  def up_to_date?(source : String)
    if Dir.exists?(@src) && HTTPHelper.url? source
      HTTPHelper.get_string(source.gsub("tarball", "commits")) =~ /(?<=datetime=").*T[0-9][0-9]:/
      return $0.starts_with? File.info(@src.rchop).modification_time.to_utc.to_s("%Y-%m-%dT%H:")
    end
    false
  end

  # Download a cache of package sources
  def update(source : String, force : Bool = false)
    # Update cache if older than 2 days
    source_dir = @src.rchop
    if force || (!File.symlink?(source_dir) && !up_to_date? source)
      if File.symlink? source_dir
        File.delete source_dir
      else
        FileUtils.rm_rf @src
      end
      if HTTPHelper.url? source
        Log.info "downloading packages source", source
        file = @path + '/' + File.basename source
        HTTPHelper.get_file source, file
        Host.exec "/bin/tar", {"zxf", file, "-C", @path}
        File.delete file
        File.rename Dir[@path + "/*packages-source*"][0], @src
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
        packages.delete library.pkg.name
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
