struct Tasks::Build
  getter package : String
  getter name : String
  getter prefix : String
  getter pkgdir : String
  getter pkg : YAML::Any
  getter version : String
  getter exists = false
  getter deps = Hash(String, String).new
  @vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars, &@log : String, String, String -> Nil)
    @prefix = @vars["prefix"]
    @package = @vars["package"].split(':')[0]

    raise "package doesn't exists: " + @package if !File.exists? "#{CACHE}/#{@package}/pkg.yml"

    @log.call "INFO", "calculing informations", "#{CACHE}/#{@package}/pkg.yml"
    @pkg = YAML.parse File.read "#{CACHE}/#{@package}/pkg.yml"
    @version = vars["version"] = getversion.not_nil!
    @vars["package"] = @package
    @name = vars["name"] = "#{@package}_#{@version}"
    @pkgdir = vars["pkgdir"] = "#{@prefix}/#{@name}"

    @arch_alias = vars["arch_alias"] = if @pkg["version"]["alias"]? && @pkg["version"]["alias"][Localhost.arch]?
                                         @pkg["version"]["alias"][Localhost.arch].as_s
                                       else
                                         Localhost.arch
                                       end

    if File.exists? @pkgdir
      @log.call "INFO", "already present", @pkgdir
      @exists = true
    end
    # keep the latest ones for each dependency
    @log.call "INFO", "calculing package dependencies", @package
    Tasks::Deps.new(&@log).get(YAML.parse(File.read "#{CACHE}/#{@package}/pkg.yml"), @pkgdir).map { |k, v| @deps[k] = v[0] }
  end

  private def getversion
    begin
      if @vars["version"]?
        ver = @vars["version"]
      elsif @vars["tag"]?
        tag = @vars["tag"]
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
          /#{regex}/.match(HTTPget.string src).not_nil![0]?
        else
          src
        end
      end
    rescue ex
      raise "can't obtain the version: " + ex.to_s
    end
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
    FileUtils.cp_r "#{CACHE}/#{@package}", @pkgdir

    # Build dependencies
    Tasks::Deps.new(&@log).build @vars.reject("--contained"), @deps

    if @pkg["tasks"]? && @pkg["tasks"]["build"]?
      @log.call "INFO", "building", @package
      Cmd::Run.new @pkg["tasks"]["build"].as_a, @vars, &@log
      # Standard package build
    else
      @log.call "INFO", "standard building", @package
      Dir.cd @pkgdir do
        package = "#{@package}-static_#{@version}_#{Localhost.kernel}_#{Localhost.arch}"
        @log.call "INFO", "downloading", @vars["mirror"] + package + ".tar.xz"
        HTTPget.file @vars["mirror"] + package + ".tar.xz"
        @log.call "INFO", "extracting", @vars["mirror"] + package + ".tar.xz"
        Exec.new "/bin/tar", ["Jxf", package + ".tar.xz"]
        Dir[package + "/*"].each { |entry| File.rename entry, "./" + File.basename entry }
        File.delete package + ".tar.xz"
        FileUtils.rm_r package
      end
    end
    FileUtils.rm_rf @pkgdir + "/lib" if pkg["type"] == "app"
    @log.call "INFO", "build completed", @pkgdir
  end
end
