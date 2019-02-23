require "./program_data"

struct Prefix::Pkg
  include ProgramData
  getter package : String,
    version : String

  protected def initialize(@prefix : Prefix, name : String, version : String? = nil, @pkg_file : PkgFile? = nil, @src : Src? = nil)
    if version
      @package, @version = name, version
      @name = @package + '_' + @version
    elsif name.includes? '_'
      @name = name
      @package, @version = name.split '_', limit: 2
    elsif name.includes? ':'
      @name = name
      @package, @version = name.split ':', limit: 2
    else
      raise "no version provided for #{name}"
    end

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
    App.new @prefix, app_name, pkg_file
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

  def build(vars : Hash(String, String))
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
        package_mirror = vars["mirror"] + '/' + package_archive
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

  def delete
    FileUtils.rm_rf @path
    Log.info "package deleted", @path
  end
end
