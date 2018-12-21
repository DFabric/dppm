struct Manager::Package::Build
  getter package : String,
    name : String,
    src : Prefix::Src,
    pkg : Prefix::Pkg,
    version : String,
    exists = false,
    deps = Hash(String, String).new,
    vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars : Hash(String, String), prefix : Prefix)
    parsed_package = @vars["package"].split(':')
    @package = @vars["package"] = parsed_package[0]

    @src = Prefix::Src.new prefix, @package
    @version = vars["version"] = getversion parsed_package[1]?
    @name = @vars["name"] = @package + '_' + @version

    @pkg = @src.new_pkg @name
    @vars["basedir"] = @pkg.path

    @arch_alias = @vars["arch_alias"] = if (aliases = @src.pkg_file.aliases) && (version_alias = aliases[Host.arch]?)
                                          version_alias
                                        else
                                          Host.arch
                                        end

    if File.exists? @pkg.path
      Log.info "already present", @pkg.path
      @exists = true
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @package
    Deps.new(prefix, @pkg.lib).resolve(@src.pkg_file).each do |dep_pkg_file, versions|
      @deps[dep_pkg_file.package] = if versions.includes?(latest = Version.from_tag "latest", dep_pkg_file)
                                      latest
                                    else
                                      versions[0]
                                    end
    end
  end

  private def getversion(package_tag : String? = nil) : String
    if ver = @vars["version"]?
    elsif tag = @vars["tag"]?
    elsif tag = package_tag
      ver = tag if tag =~ /^([0-9]+\.[0-9]+\.[0-9]+)/
      # Set a default tag if not set
    else
      tag = "latest"
    end
    if ver
      # Check if the version number is available
      raise "not available version number: " + ver if !Version.all(Host.kernel, Host.arch, @src.pkg_file.version).includes? ver
      ver
    elsif tag
      Version.from_tag tag, @src.pkg_file
    else
      raise "fail to get a version"
    end
  rescue ex
    raise "can't obtain a version: #{ex}"
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      str << "\ndeps: " << @deps.map { |k, v| k + ':' + v }.join(", ") if !@deps.empty?
    end
  end

  def run
    raise "package already present: " + @pkg.path if @exists

    # Copy the sources to the @package directory to build
    FileUtils.cp_r(@src.path, @pkg.path)

    # Build dependencies
    Deps.new(@pkg.prefix, @pkg.lib).build @vars.dup, @deps

    if (tasks = @src.pkg_file.tasks) && (build_task = tasks["build"]?)
      Log.info "building", @package
      Dir.cd(@pkg.path) { Cmd.new(@vars.dup).run build_task.as_a }
      # Standard package build
    else
      Log.info "standard building", @package

      working_directory = if @src.pkg_file.type == "app"
                            Dir.mkdir @pkg.app_dir
                            @pkg.app_dir
                          else
                            @pkg.path
                          end
      Dir.cd working_directory do
        package_full_name = "#{@package}-static_#{@version}_#{Host.kernel}_#{Host.arch}"
        package_archive = package_full_name + ".tar.xz"
        package_mirror = @vars["mirror"] + '/' + package_archive
        Log.info "downloading", package_mirror
        HTTPget.file package_mirror
        Log.info "extracting", package_mirror
        Manager.exec "/bin/tar", {"Jxf", package_archive}

        # Move out files from the archive folder
        Dir.cd package_full_name do
          move "./"
        end
        FileUtils.rm_r({package_archive, package_full_name})
      end
    end
    FileUtils.rm_rf @pkg.lib if @src.pkg_file.type == "app"
    Log.info "build completed", @pkg.path
    self
  rescue ex
    FileUtils.rm_rf @pkg.path
    raise "build failed - package deleted: #{@pkg.path}:\n#{ex}"
  end

  private def move(path)
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
end
