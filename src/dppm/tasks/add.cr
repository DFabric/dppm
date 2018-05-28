struct Tasks::Add
  getter package : String = ""
  getter name : String
  getter pkgdir : String
  getter pkg : YAML::Any
  getter version : String
  getter vars : Hash(String, String)
  @add_user_group = false
  @deps = Hash(String, String).new
  @path : Tasks::Path

  def initialize(@vars, @path)
    # Build missing dependencies
    @build = Tasks::Build.new vars.dup, path
    @version = @vars["version"] = @build.version
    @package = @vars["package"] = @build.package
    @deps = @build.deps
    @pkg = @build.pkg
    Log.info "getting name", @package

    getname
    @name = vars["name"]
    @pkgdir = @vars["pkgdir"] = "#{path.app}/#{@name}"

    if owner = vars["owner"]?
      @vars["user"] = @vars["group"] = owner
    elsif @vars["user"]? || @vars["group"]?
      raise "either both or none of user and group need to be specified"
    else
      @vars["user"] = @vars["group"] = @name
      @add_user_group = true
    end

    Log.info "calculing informations", "#{path.src}/#{@package}/pkg.yml"

    # Checks
    raise "directory already exists: " + @pkgdir if File.exists? @pkgdir
    Localhost.service.check_availability @pkg["type"], @name

    # Default variables
    unset_vars = Array(String).new
    if pkg_config = @pkg["config"]?
      conf = ConfFile::Config.new "#{path.src}/#{@package}"
      pkg_config.as_h.each_key do |var|
        variable = var.to_s
        if !@vars[variable]?
          key = conf.get(variable).to_s
          if key.empty?
            unset_vars << variable
          else
            @vars[variable] = key
            Log.info "default value set for unset variable", var.to_s + ": " + @vars[var.to_s]
          end
        end
      end
    end
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?
    @vars["port"] = port if vars["port"]?
  end

  private def getname
    # lib and others
    if @pkg["type"] == "lib"
      raise "only applications can be added to the system"
    elsif @pkg["type"] == "app"
      @vars["name"] ||= Utils.gen_name @package
      @vars["name"].ascii_alphanumeric_underscore? || raise "the name contains other characters than `a-z`, `0-9` and `_`: #{@vars["name"]}"
    else
      raise "unknow type: #{@pkg["type"]}"
    end
  end

  private def port
    raise "the port must be an Int32 number: " + port if !@vars["port"].to_i?
    Localhost.port(@vars["port"].to_i).to_s
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      str << "\ndeps: " << @deps.map { |k, v| "#{k}:#{v}" }.join(", ") if !@deps.empty?
    end
  end

  def run
    Log.info "adding to the system", @name
    FileUtils.mkdir_p [@path.app, @path.pkg]

    # Create the new application
    @build.run if !@build.exists
    Dir.mkdir @pkgdir
    if vars.has_key?("--contained")
      FileUtils.cp_r @build.pkgdir + "/app", @pkgdir + "/app"
      FileUtils.cp @build.pkgdir + "/pkg.yml", @pkgdir + "/pkg.yml"
    else
      File.symlink @build.pkgdir + "/app", @pkgdir + "/app"
      File.symlink @build.pkgdir + "/pkg.yml", @pkgdir + "/pkg.yml"
    end

    Tasks::Deps.new(@path).build @vars.dup, @deps

    # Copy configurations
    Log.info "copying configurations", @name
    {"/etc", "/srv", "/log"}.each do |dir|
      if !File.exists? @pkgdir + dir
        if File.exists? @build.pkgdir + dir
          FileUtils.cp_r @build.pkgdir + dir, @pkgdir + dir
        else
          Dir.mkdir @pkgdir + dir
        end
      end
    end

    # Set configuration variables in files
    Log.info "setting configuration variables", @name
    if pkg_config = @pkg["config"]?
      conf = ConfFile::Config.new @pkgdir
      pkg_config.as_h.each_key do |var|
        variable = var.to_s
        conf.set variable, @vars[variable] if @vars[variable]?
      end
    end

    # php-fpm based application
    if @pkg["keywords"].includes? "php-fpm"
      php_fpm = YAML.parse File.read(@pkgdir + "/lib/php/pkg.yml")
      @pkg.as_h["exec"] = php_fpm.as_h["exec"]

      # Copy files and directories if not present
      FileUtils.cp(@pkgdir + "/lib/php/etc/php-fpm.conf.default", @pkgdir + "/etc/php-fpm.conf") if !File.exists? @pkgdir + "/etc/php-fpm.conf"
      Dir.mkdir @pkgdir + "/etc/php-fpm.d" if !File.exists? @pkgdir + "/etc/php-fpm.d"
      FileUtils.cp(@pkgdir + "/lib/php/etc/php-fpm.d/www.conf.default", @pkgdir + "/etc/php-fpm.d/www.conf") if !File.exists? @pkgdir + "/etc/php-fpm.d/www.conf"

      Dir.cd @pkgdir { Cmd::Run.new(@vars.dup).run @pkg["tasks"]["build"].as_a }
    end

    # Running the add task
    Log.info "running configuration tasks", @package
    if add_task = @pkg["tasks"]["add"]?
      Dir.cd @pkgdir { Cmd::Run.new(@vars.dup).run add_task.as_a }
    end

    if Localhost.service.writable?
      # Set the user and group owner
      Owner.add(@vars["user"], @pkg["description"]) if @add_user_group
      Utils.chown_r @pkgdir, Owner.to_id(@vars["user"], "uid"), Owner.to_id(@vars["group"], "gid")

      # Create system services
      Localhost.service.create @pkg, @vars
      Localhost.service.system.new(@name).link @pkgdir
      Log.info Localhost.service.name + " system service added", @name
    else
      Log.warn "root execution needed for system service addition", @name
    end

    Log.info "add completed", @pkgdir
  rescue
    raise "add failed, deleting: " + @pkgdir
    FileUtils.rm_rf @pkgdir
  end
end
