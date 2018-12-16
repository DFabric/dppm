struct Manager::Package::Build
  getter package : String,
    name : String,
    pkgdir : String,
    path : Path,
    pkg_file : PkgFile,
    version : String,
    exists = false,
    deps = Hash(String, String).new,
    vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars)
    @path = Path.new vars["prefix"]
    @package = @vars["package"].split(':')[0]
    @pkg_file = PkgFile.new @path.src + @package
    @version = vars["version"] = getversion
    @vars["package"] = @package
    @name = @vars["name"] = @package + '_' + @version
    @pkgdir = @vars["pkgdir"] = path.pkg + @name

    @arch_alias = @vars["arch_alias"] = if (aliases = @pkg_file.aliases) && (version_alias = aliases[Host.arch]?)
                                          version_alias
                                        else
                                          Host.arch
                                        end

    if File.exists? @pkgdir
      Log.info "already present", @pkgdir
      @exists = true
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @package
    Deps.new(@path, @pkgdir).resolve(@pkg_file).each do |dep_pkg_file, versions|
      @deps[dep_pkg_file.package] = if versions.includes?(latest = Version.from_tag "latest", dep_pkg_file)
                                      latest
                                    else
                                      versions[0]
                                    end
    end
  end

  private def getversion
    if ver = @vars["version"]?
    elsif tag = @vars["tag"]?
    elsif tag = @vars["package"].split(':')[1]?
      ver = tag if tag =~ /^([0-9]+\.[0-9]+\.[0-9]+)/
      # Set a default tag if not set
    else
      tag = "latest"
    end
    if ver
      # Check if the version number is available
      raise "not available version number: " + ver if !Version.all(Host.kernel, Host.arch, @pkg_file.version).includes? ver
      ver
    elsif tag
      Version.from_tag tag, pkg_file
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
    raise "package already present: " + @pkgdir if @exists

    begin
      # Copy the sources to the @package directory to build
      FileUtils.cp_r(@path.src + package, @pkgdir)

      # Build dependencies
      Deps.new(@path, @pkgdir).build @vars.dup, @deps

      if (tasks = @pkg_file.tasks) && (build_task = tasks["build"]?)
        Log.info "building", @package
        Dir.cd @pkgdir { Cmd.new(@vars.dup).run build_task.as_a }
        # Standard package build
      else
        Log.info "standard building", @package

        working_directory = if pkg_file.type == "app"
                              Dir.mkdir(app = @pkgdir + "/app")
                              app
                            else
                              @pkgdir
                            end
        Dir.cd working_directory do
          package_full_name = "#{@package}-static_#{@version}_#{Host.kernel}_#{Host.arch}"
          package_archive = package_full_name + ".tar.xz"
          package_mirror = @vars["mirror"] + '/' + package_archive
          Log.info "downloading", package_mirror
          HTTPget.file package_mirror
          Log.info "extracting", package_mirror
          Exec.new "/bin/tar", ["Jxf", package_archive]

          # Move out files from the archive folder
          Dir.cd package_full_name do
            move "./"
          end
          FileUtils.rm_r({package_archive, package_full_name})
        end
      end
      FileUtils.rm_rf @pkgdir + "/lib" if pkg_file.type == "app"
      Log.info "build completed", @pkgdir
      self
    rescue ex
      FileUtils.rm_rf @pkgdir
      raise "build failed - package deleted: #{@pkgdir}:\n#{ex}"
    end
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
