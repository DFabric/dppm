struct Package::Add
  getter package : String = "",
    name : String,
    pkgdir : String,
    pkg : YAML::Any,
    version : String,
    vars : Hash(String, String),
    path : Package::Path
  @add_user = false
  @add_group = false
  @deps = Hash(String, String).new
  @features : YAML::Any?
  @socket : Bool
  @contained : Bool

  def initialize(@vars, @socket : Bool, @contained : Bool)
    # Build missing dependencies
    @build = Package::Build.new vars.dup
    @path = @build.path
    @version = @vars["version"] = @build.version
    @package = @vars["package"] = @build.package
    @pkg = @build.pkg
    @features = @pkg["features"]?

    Log.info "getting name", @package
    getname
    @name = vars["name"]
    @pkgdir = @vars["pkgdir"] = "#{@path.app}/#{@name}"

    @deps = @build.deps

    Log.info "calculing informations", "#{path.src}/#{@package}/pkg.yml"

    # Checks
    raise "directory already exists: " + @pkgdir if File.exists? @pkgdir
    Localhost.service.check_availability @pkg["type"], @name

    # Check database type
    if (db_type = @vars["database_type"]?) && (databases = @pkg["databases"]?)
      raise "unsupported database type: " + db_type if !databases[db_type]?
    end

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

    owner_id = Owner.available_id.to_s

    # An user uid and a group gid is required
    if uid = @vars["uid"]?
      @vars["user"] = Owner.to_user uid
    else
      if user = @vars["user"]?
        @vars["uid"] = Owner.to_user user
      else
        @vars["user"] = @name
        @vars["uid"] = owner_id
        @add_user = true
      end
    end
    if gid = @vars["gid"]?
      @vars["group"] = Owner.to_group gid
    else
      if group = @vars["group"]?
        @vars["gid"] = Owner.to_group group
      else
        @vars["group"] = @name
        @vars["gid"] = owner_id
        @add_group = true
      end
    end

    port
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
    if port_string = @vars["port"]?
      Log.info "checking ports availability", port_string
      @vars["port"] = Localhost.port(port_string.to_i).to_s
    end
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

    app_contained = @contained
    if (features = @features) && features["contained"].to_s == "true"
      Log.warn "must be self-contained ", @pkg["package"].as_s
      app_contained = true
    end
    if app_contained
      Log.info "copying from " + @build.pkgdir, @pkgdir
      FileUtils.cp_r @build.pkgdir + "/app", @pkgdir + "/app"
      FileUtils.cp_r @build.pkgdir + "/pkg.yml", @pkgdir + "/pkg.yml"
    else
      Log.info "creating symlinks from " + @build.pkgdir, @pkgdir
      File.symlink @build.pkgdir + "/app", @pkgdir + "/app"
      File.symlink @build.pkgdir + "/pkg.yml", @pkgdir + "/pkg.yml"
    end

    # Build and add missing dependencies
    Package::Deps.new(@path).build @vars.dup, @deps, @contained

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
    File.chmod(@pkgdir + "/etc", 0o500)
    File.chmod(@pkgdir + "/srv", 0o550)
    File.chmod(@pkgdir + "/log", 0o500)

    # Set configuration variables in files
    Log.info "setting configuration variables", @name
    if pkg_config = @pkg["config"]?
      conf = ConfFile::Config.new @pkgdir
      pkg_config.as_h.each_key do |var|
        variable = var.to_s
        if variable_value = @vars[variable]?
          conf.set variable, variable_value
        end
      end
    end

    # php-fpm based application
    # if "php-fpm"
    # php_fpm = YAML.parse File.read(@pkgdir + "/lib/php/pkg.yml")
    # @pkg.as_h[YAML::Any.new "exec"] = YAML::Any.new php_fpm["exec"].as_h

    # # Copy files and directories if not present
    # FileUtils.cp(@pkgdir + "/lib/php/etc/php-fpm.conf.default", @pkgdir + "/etc/php-fpm.conf") if !File.exists? @pkgdir + "/etc/php-fpm.conf"
    # Dir.mkdir @pkgdir + "/etc/php-fpm.d" if !File.exists? @pkgdir + "/etc/php-fpm.d"
    # FileUtils.cp(@pkgdir + "/lib/php/etc/php-fpm.d/www.conf.default", @pkgdir + "/etc/php-fpm.d/www.conf") if !File.exists? @pkgdir + "/etc/php-fpm.d/www.conf"

    # Dir.cd @pkgdir { Cmd::Run.new(@vars.dup).run @pkg["tasks"]["build"].as_a }
    # end

    # Running the add task
    Log.info "running configuration tasks", @package
    if (tasks = @pkg["tasks"]?) && (add_task = tasks["add"]?)
      Dir.cd @pkgdir { Cmd::Run.new(@vars.dup).run add_task.as_a }
    end

    if Localhost.service.writable?
      # Set the user and group owner
      Owner.add_user(@vars["uid"], @vars["user"], @pkg["description"]) if @add_user
      Owner.add_group(@vars["gid"], @vars["group"]) if @add_group
      Utils.chown_r @pkgdir, @vars["uid"].to_i, @vars["gid"].to_i

      # Create system services
      Localhost.service.create @pkg, @vars
      Localhost.service.system.new(@name).link @pkgdir
      Log.info Localhost.service.name + " system service added", @name
    else
      Log.warn "root execution needed for system service addition", @name
    end

    Log.info "add completed", @pkgdir
  rescue ex
    FileUtils.rm_rf @pkgdir
    Log.error "add failed, deleting: #{@pkgdir}:\n#{ex}"
  end
end
