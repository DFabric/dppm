struct Package::Build
  getter package : String,
    name : String,
    pkgdir : String,
    pkg : YAML::Any,
    version : String,
    exists = false,
    deps = Hash(String, String).new,
    path : Package::Path,
    vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars)
    @path = Path.new vars["prefix"]
    @package = @vars["package"].split(':')[0]
    raise "package doesn't exists: " + @package if !File.exists? "#{@path.src}/#{@package}/pkg.yml"

    Log.info "calculing informations", "#{@path.src}/#{@package}/pkg.yml"
    @pkg = YAML.parse File.read "#{@path.src}/#{@package}/pkg.yml"
    @version = vars["version"] = getversion
    @vars["package"] = @package
    @name = @vars["name"] = "#{@package}_#{@version}"
    @pkgdir = @vars["pkgdir"] = "#{path.pkg}/#{@name}"

    @arch_alias = @vars["arch_alias"] = if (aliases = @pkg["aliases"]?) && (version_alias = aliases[Localhost.arch]?)
                                          version_alias.as_s
                                        else
                                          Localhost.arch
                                        end

    if File.exists? @pkgdir
      Log.info "already present", @pkgdir
      @exists = true
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @package
    Package::Deps.new(@path).get(@pkg, @pkgdir).each { |k, v| @deps[k] = v[0] }
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
      raise "not available version number: " + ver if !Version.get(Localhost.kernel, Localhost.arch, @pkg["version"]).includes? ver
      ver
    elsif tag
      src = @pkg["tags"][tag]["src"].as_s
      # Test if the src is an URL or a version number
      if Utils.is_http? src
        regex = if regex_tag = @pkg["tags"][tag]["regex"]?
                  regex_tag
                else
                  @pkg["tags"]["self"]["regex"]
                end.as_s
        if /#{regex}/ =~ HTTPget.string(src)
          $0
        else
          raise "fail to apply the `#{regex}` regex to #{src}"
        end
      else
        src
      end
    else
      raise "fail to get a version"
    end
  rescue ex
    raise "can't obtain the version: #{ex}"
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      str << "\ndeps: " << @deps.map { |k, v| "#{k}:#{v}" }.join(", ") if !@deps.empty?
    end
  end

  def run
    raise "package already present: " + @pkgdir if @exists

    # Copy the sources to the @package directory to build
    FileUtils.cp_r "#{@path.src}/#{@package}", @pkgdir

    # Build dependencies
    Package::Deps.new(@path).build @vars.dup, @deps

    if (tasks = @pkg["tasks"]?) && (build_task = tasks["build"]?)
      Log.info "building", @package
      Dir.cd @pkgdir { Cmd::Run.new(@vars.dup).run build_task.as_a }
      # Standard package build
    else
      Log.info "standard building", @package
      Dir.cd @pkgdir do
        package_full = "#{@package}-static_#{@version}_#{Localhost.kernel}_#{Localhost.arch}"
        package_archive = package_full + ".tar.xz"
        package_mirror = @vars["mirror"] + package_archive
        Log.info "downloading", package_mirror
        HTTPget.file package_mirror
        Log.info "extracting", package_mirror
        Exec.new "/bin/tar", ["Jxf", package_archive]
        Dir[package_full + "/*"].each { |entry| File.rename entry, "./" + File.basename entry }
        File.delete package_archive
        FileUtils.rm_r package_full
      end
    end
    FileUtils.rm_rf @pkgdir + "/lib" if pkg["type"] == "app"
    Log.info "build completed", @pkgdir
  rescue ex
    FileUtils.rm_rf @pkgdir
    raise "build failed, deleting: #{@pkgdir}:\n#{ex}"
  end
end
