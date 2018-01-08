require "yaml"

struct Tasks::Build
  getter package : String
  getter name : String
  getter prefix : String
  getter pkgdir : String
  getter vars : Hash(String, String)
  getter pkg
  getter version : String
  @deps = Hash(String, String).new
  @arch_alias : String

  def initialize(vars, &@log : String, String, String -> Nil)
    @log = log
    @vars = vars
    @prefix = @vars["prefix"]
    @package = @vars["package"].split(':')[0]

    @log.call "INFO", "calculing informations", CACHE + @package + "/pkg.yml"
    @pkg = YAML.parse File.read CACHE + @package + "/pkg.yml"
    @version = getversion.not_nil!
    @name = getname
    @pkgdir = @prefix + '/' + @name + '/'
    @vars["pkgdir"] = @pkgdir
    raise "already existing: " + @pkgdir if File.exists? @pkgdir

    @arch_alias = if @pkg["arch"]["alias"]? && @pkg["arch"]["alias"][HOST.arch]?
                    @pkg["arch"]["alias"][HOST.arch].as_s
                  else
                    HOST.arch
                  end

    # keep the latest ones for each dependency
    @log.call "INFO", "calculing package dependencies", @package
    Tasks::Deps.new(&@log).get(YAML.parse(File.read CACHE + @package + "/pkg.yml"), @pkgdir).map { |k, v| @deps[k] = v[0] }

    {% for var in ["version", "name", "package", "pkgdir", "arch_alias"] %}
    {
      @vars[{{var}}] = @{{var.id}}.not_nil!
    }
    {% end %}
  end

  private def getname
    # lib and others
    if @pkg["type"] == "lib"
      @package + '_' + @version
      # Only this characters are allowed
    elsif @pkg["type"] == "app"
      name = @vars["name"]? ? @vars["name"] : @package
      !name.match(/^[a-zA-Z0-9-.]+$/) ? raise "the name contains other characters than a-z, A-Z, 0-9, - and .: " + name : name
    else
      raise "unknow type: #{@pkg["type"]}"
    end
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
        raise "not available version number: " + ver if !Version.get(HOST.kernel, HOST.arch, @pkg["arch"]).includes? ver
        ver
      elsif tag
        src = @pkg["tags"][tag]["src"].as_s
        # Test if the src is an URL or a version number
        if src =~ /^https?:\/\/.*/
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
      str << @vars.map { |k, v| '\n' + k + ": " + v }.join
      str << "\ndeps: " << @deps.map { |k, v| k + ':' + v }.join(", ") if !@deps.empty?
    end
  end

  def run
    # Copy the sources to the @package directory to build
    FileUtils.cp_r CACHE + @package, @pkgdir

    # Build dependencies
    Tasks::Deps.new(&@log).build @vars, @deps if !@deps.empty?

    if @pkg["tasks"]?
      @log.call "INFO", "building", @package
      HOST.run @pkg["tasks"]["build"].as_a, @vars, &@log
      # Standard package build
    else
      @log.call "INFO", "standard building", @package
      Dir.cd vars["pkgdir"]
      package = @package + "-static" + '_' + @vars["version"] + '_' + HOST.kernel + '_' + HOST.arch
      @log.call "INFO", "downloading", @vars["mirror"] + package + ".tar.xz"
      HTTPget.file @vars["mirror"] + package + ".tar.xz"
      @log.call "INFO", "extracting", @vars["mirror"] + package + ".tar.xz"
      Exec.new "/bin/tar", ["Jxf", package + ".tar.xz"]
      Dir[package + "/*"].each { |entry| File.rename entry, "./" + File.basename entry }
      File.delete package + ".tar.xz"
      FileUtils.rm_r package
    end
    FileUtils.mkdir_p [@pkgdir + "etc", @pkgdir + "srv"] if @pkg["type"].as_s == "app"
    @log.call "INFO", "build completed", @pkgdir
  end
end
