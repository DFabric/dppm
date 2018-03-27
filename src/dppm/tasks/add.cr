struct Tasks::Add
  @deps = Hash(String, String).new
  @vars : Hash(String, String)
  @package : String
  @prefix : String
  @pkgdir : String

  def initialize(@vars, &@log : String, String, String -> Nil)
    @prefix = vars["prefix"]
    @package = vars["package"]
    @pkgdir = @prefix + '/' + @package + '/'
    @vars["pkgdir"] = @pkgdir
    @vars["name"] = @package
    if vars["owner"]?
      @vars["user"] = vars["owner"]
      @vars["group"] = vars["owner"]
    else
      dir = File.stat @pkgdir
      @vars["user"] ||= Owner.from_id dir.uid, "uid"
      @vars["group"] ||= Owner.from_id dir.gid, "gid"
    end

    @log.call "INFO", "calculing informations", "#{CACHE}/#{@package}/pkg.yml"
    @pkg = YAML.parse File.read "#{CACHE}/#{@package}/pkg.yml"

    # Checks
    Tasks.pkg_exists? @pkgdir
    Service.check_availability @pkg["type"], @package, &log

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

    # php-fpm based application
    if @pkg["keywords"].includes? "php-fpm"
      php_fpm = YAML.parse File.read(@pkgdir + "lib/php/pkg.yml")
      @pkg.as_h["exec"] = php_fpm.as_h["exec"]

      # Copy files and directories if not present
      FileUtils.cp(@pkgdir + "lib/php/etc/php-fpm.conf.default", @pkgdir + "etc/php-fpm.conf") if !File.exists? @pkgdir + "etc/php-fpm.conf"
      Dir.mkdir @pkgdir + "etc/php-fpm.d" if !File.exists? @pkgdir + "etc/php-fpm.d"
      FileUtils.cp(@pkgdir + "lib/php/etc/php-fpm.d/www.conf.default", @pkgdir + "etc/php-fpm.d/www.conf") if !File.exists? @pkgdir + "etc/php-fpm.d/www.conf"

      HOST.run php_fpm["tasks"]["add"].as_a, @vars, &@log
    end

    # Running the add task
    @log.call "INFO", "running configuration tasks", @package
    HOST.run @pkg["tasks"]["add"].as_a, @vars, &@log if @pkg["tasks"]["add"]?

    # Set the user and group owner
    Utils.chown_r @pkgdir, Owner.to_id(@vars["user"], "uid"), Owner.to_id(@vars["group"], "gid")

    # Create system services
    if HOST.service.writable?
      HOST.service.create @pkg, @vars, &@log
      Service.system.new(@vars["package"]).link @vars["pkgdir"]
      @log.call "INFO", HOST.service.name + " system service added", @vars["package"]
    else
      @log.call "WARN", "root execution needed for system service addition", @vars["package"]
    end

    @log.call "INFO", "add completed", @pkgdir
  end
end
