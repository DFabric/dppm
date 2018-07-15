struct Tasks::Build
  getter package : String
  getter name : String
  getter pkgdir : String
  getter pkg : YAML::Any
  getter version : String
  getter exists = false
  getter deps = Hash(String, String).new
  @vars : Hash(String, String)
  @arch_alias : String
  @path : Tasks::Path

  def initialize(@vars, @path)
    @package = @vars["package"].split(':')[0]
    raise "package doesn't exists: " + @package if !File.exists? "#{path.src}/#{@package}/pkg.yml"

    Log.info "calculing informations", "#{path.src}/#{@package}/pkg.yml"
    @pkg = YAML.parse File.read "#{path.src}/#{@package}/pkg.yml"
    @version = vars["version"] = getversion
    @vars["package"] = @package
    @name = vars["name"] = "#{@package}_#{@version}"
    @pkgdir = vars["pkgdir"] = "#{path.pkg}/#{@name}"

    @arch_alias = vars["arch_alias"] = if @pkg["version"]["alias"]? && (version_alias = @pkg["version"]["alias"][Localhost.arch].as_s?)
                                         version_alias
                                       else
                                         Localhost.arch
                                       end

    if File.exists? @pkgdir
      Log.info "already present", @pkgdir
      @exists = true
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @package
    Tasks::Deps.new(@path).get(@pkg, @pkgdir).each { |k, v| @deps[k] = v[0] }
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
        regex = if @pkg["tags"][tag]["regex"]?
                  @pkg["tags"][tag]["regex"]
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
    raise "can't obtain the version: " + ex.to_s
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
    Tasks::Deps.new(@path).build @vars.reject("--contained"), @deps
    if @pkg["tasks"]? && (build_task = @pkg["tasks"]["build"]?)
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
    # FileUtils.rm_rf @pkgdir
    raise "build failed, deleting: #{@pkgdir}:\n#{ex}"
  end
end
