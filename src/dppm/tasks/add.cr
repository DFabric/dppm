struct Tasks::Add
  @deps = Hash(String, String).new
  @vars : Hash(String, String)
  @package : String
  @prefix : String
  @pkgdir : String

  def initialize(vars, &log : String, String, String -> Nil)
    @log = log
    @vars = vars
    @prefix = vars["prefix"]
    @package = vars["package"]
    @pkgdir = @prefix + '/' + @package + '/'
    @vars["pkgdir"] = @pkgdir
    @vars["name"] = @package
    dir = File.stat @pkgdir
    @vars["user"] = Owner.from_id dir.uid, "uid" if !vars["user"]?
    @vars["group"] = Owner.from_id dir.gid, "gid" if !vars["group"]?

    @log.call "INFO", "obtaining pkg", CACHE + @package + "/pkg.yml"
    @pkg = YAML.parse File.read CACHE + @package + "/pkg.yml"

    # Checks
    Tasks.pkg_exists? @pkgdir
    Tasks.checks @pkg["type"], @package, &log

    # Default variables
    unset_vars = Array(String).new
    if @pkg["config"]?
      conf = ConfFile::Config.new @pkgdir
      @pkg["config"].as_h.each_key do |var|
        if !@vars[var.to_s]?
          begin
            @vars[var.to_s] = conf.get(var.to_s).to_s
            @log.call "INFO", "default value set for unset variable", var.to_s + ": " + @vars[var.to_s]
          rescue
            unset_vars << var.to_s
          end
        end
      end
    end
    @log.call "WARN", "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?
    @vars["port"] = port if vars["port"]?

    # Build missing dependencies
    @log.call "INFO", "checking dependencies", @package
    Tasks::Deps.new(&log).get(YAML.parse(File.read @pkgdir + "/pkg.yml"), @pkgdir).map { |k, v| @deps[k] = v[0] }
  end

  private def port
    if @vars["port"].to_i?
      HOST.port(@vars["port"].to_i, &@log).to_s
    else
      raise "the port must be an Int32 number: " + port
    end
  end

  def simulate
    String.build do |str|
      str << @vars.map { |k, v| '\n' + k + ": " + v }.join
      str << "\ndeps: " << @deps.map { |k, v| k + ':' + v }.join(", ") if !@deps.empty?
    end
  end

  def run
    @log.call "INFO", "adding to the system", @package
    # Set configuration variables in files
    @log.call "INFO", "setting configuration variables", @package
    if @pkg["config"]?
      conf = ConfFile::Config.new @pkgdir
      @pkg["config"].as_h.each_key do |var|
        conf.set var.to_s, @vars[var.to_s] if @vars[var.to_s]?
      end
    end

    # Build missing dependencies
    Tasks::Deps.new(&@log).build @vars, @deps if !@deps.empty?

    # Running the add task
    @log.call "INFO", "running configuration tasks", @package
    HOST.run @pkg["tasks"]["add"].as_a, @vars, &@log if @pkg["tasks"]["add"]?

    # Set the user and group owner
    Utils.chown_r @pkgdir, Owner.to_id(@vars["user"], "uid"), Owner.to_id(@vars["group"], "gid")

    # Create system services
    Service.create @pkg, @vars, &@log

    @log.call "INFO", "add completed", @pkgdir
  end
end
