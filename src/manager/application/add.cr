struct Manager::Application::Add
  getter package : String,
    name : String,
    pkgdir : String,
    path : Path,
    pkg_file : PkgFile,
    version : String,
    vars : Hash(String, String)
  @add_user = false
  @add_group = false
  @deps = Hash(String, String).new
  @socket : Bool
  @shared : Bool
  @service : Service::Systemd | Service::OpenRC | Nil

  def initialize(@vars, @shared : Bool = true, add_service : Bool = true, @socket : Bool = false)
    # Build missing dependencies
    @build = Package::Build.new vars.dup
    @path = @build.path
    @version = @vars["version"] = @build.version
    @package = @vars["package"] = @build.package
    @pkg_file = @build.pkg_file

    Log.info "getting name", @package
    getname
    @name = @vars["name"]
    if add_service && (service = ::System::Host.service?.try &.new @name)
      service.check_availability @pkg_file.type
      @service = service
    end
    @pkgdir = @vars["pkgdir"] = @path.app + @name
    raise "application directory already exists: " + @pkgdir if File.exists? @pkgdir
    @deps = @build.deps

    # Check database type
    Log.info "calculing informations", path.src + @package
    if (db_type = @vars["database_type"]?) && (databases = @pkg_file.databases)
      raise "unsupported database type: " + db_type if !databases[db_type]?
    end

    # Default variables
    unset_vars = Array(String).new
    if pkg_config = @pkg_file.config
      conf = Config::Pkg.new @pkg_file.dir, pkg_config
      pkg_config.each_key do |var|
        # Skip if a socket is used
        next if var == "port" && @socket
        if !@vars[var]?
          key = conf.get(var).to_s
          if key.empty?
            unset_vars << var
          else
            @vars[var] = key
            Log.info "default value set for unset variable", var + ": " + key
          end
        end
      end
    end
    Log.warn "default value not available for unset variables", unset_vars.join ", " if !unset_vars.empty?

    create_user_group
    raise "socket not supported by #{@pkg_file.name}" if @socket

    if !@socket && (port_string = @vars["port"]?)
      @vars["port"] = ::System.available_port(port_string.to_i).to_s
    end
  end

  # An user uid and a group gid is required
  private def create_user_group
    if ::System::Owner.root?
      owner_id = ::System::Owner.available_id.to_s
      if uid = @vars["uid"]?
        @vars["user"] = ::System::Owner.to_user uid
      elsif user = @vars["user"]?
        @vars["uid"] = ::System::Owner.to_user user
      else
        @vars["user"] = '_' + @name
        @vars["uid"] = owner_id
        @add_user = true
      end
      if gid = @vars["gid"]?
        @vars["group"] = ::System::Owner.to_group gid
      elsif group = @vars["group"]?
        @vars["gid"] = ::System::Owner.to_group group
      else
        @vars["group"] = '_' + @name
        @vars["gid"] = owner_id
        @add_group = true
      end
    else
      @vars["group"], @vars["gid"] = ::System::Owner.current_uid_gid.map &.to_s
    end
  end

  private def getname
    # lib and others
    case @pkg_file.type
    when "lib"
      raise "only applications can be added to the system"
    when "app"
      @vars["name"] ||= Utils.gen_name @package
      Utils.ascii_alphanumeric_dash? @vars["name"]
    else
      raise "unknow type: #{@pkg_file.type}"
    end
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      str << "\ndeps: " << @deps.map { |k, v| k + ':' + v }.join(", ") if !@deps.empty?
    end
  end

  def run
    Log.info "adding to the system", @name
    raise "application directory already exists: " + @pkgdir if File.exists? @pkgdir

    begin
      FileUtils.mkdir_p({@path.app, @path.pkg})
      # Create the new application
      @build.run if !@build.exists
      Dir.mkdir @pkgdir

      app_shared = @shared
      if !@pkg_file.shared
        Log.warn "can't be shared, must be self-contained", @pkg_file.package
        app_shared = false
      end
      if app_shared
        Log.info "creating symlinks from " + @build.pkgdir, @pkgdir
        File.symlink @build.pkgdir + "/app", @pkgdir + "/app"
        File.symlink @build.pkg_file.path, @pkgdir + Manager::PkgFile::NAME
      else
        Log.info "copying from " + @build.pkgdir, @pkgdir
        FileUtils.cp_r @build.pkgdir + "/app", @pkgdir + "/app"
        FileUtils.cp_r @build.pkg_file.path, @pkgdir + Manager::PkgFile::NAME
      end

      # Build and add missing dependencies
      Package::Deps.new(@path).build @vars.dup, @deps, @shared

      # Copy configurations and data
      Log.info "copying configurations and data", @name
      {"/etc", "/srv", "/log"}.each do |dir|
        dest_dir = @pkgdir + dir
        src_dir = @build.pkgdir + dir
        if !File.exists? dest_dir
          if File.exists? src_dir
            FileUtils.cp_r src_dir, dest_dir
          else
            Dir.mkdir dest_dir
          end
        end
      end
      File.chmod @pkgdir + "/etc", 0o700
      File.chmod @pkgdir + "/srv", 0o750
      File.chmod @pkgdir + "/log", 0o700

      # Set configuration variables
      Log.info "setting configuration variables", @name
      if pkg_config = @pkg_file.config
        conf = Config::Pkg.new @pkgdir, pkg_config
        pkg_config.each_key do |var|
          if var == "socket"
            next
          elsif variable_value = @vars[var]?
            conf.set var, variable_value
          end
        end
      end

      # PHP-FPM based application
      if (deps = @pkg_file.deps) && deps.has_key? "php"
        php_fpm_conf = @pkgdir + "/etc/php-fpm.conf"
        FileUtils.cp(@pkgdir + "/lib/php/etc/php-fpm.conf", php_fpm_conf) if !File.exists? php_fpm_conf
        php_fpm = PkgFile.new @pkgdir + "/lib/php"
        @pkg_file.exec = php_fpm.exec
      end

      # Running the add task
      Log.info "running configuration tasks", @package
      if (tasks = @pkg_file.tasks) && (add_task = tasks["add"]?)
        Dir.cd @pkgdir { Cmd.new(@vars.dup).run add_task.as_a }
      end

      if ::System::Owner.root?
        # Set the user and group owner
        ::System::Owner.add_user(@vars["uid"], @vars["user"], @pkg_file.description, @pkgdir + "/srv") if @add_user
        ::System::Owner.add_group(@vars["gid"], @vars["group"]) if @add_group
        Utils.chown_r @pkgdir, @vars["uid"].to_i, @vars["gid"].to_i
      end

      if (service = @service)
        begin
          # Create system services
          service.create @pkg_file, @pkgdir, @vars["user"], @vars["group"]
          service.enable @pkgdir
          Log.info service.class.type + " system service added", @name
        rescue ex
          Log.warn "fail to add a system service", ex.to_s
          service.delete
        end
      end

      Log.info "add completed", @pkgdir
      Log.info "application information", @pkg_file.info
      self
    rescue ex
      FileUtils.rm_rf @pkgdir
      ::System::Owner.del_user(@vars["user"]) if @add_user
      ::System::Owner.del_group(@vars["group"]) if @add_group
      raise "add failed - application deleted: #{@pkgdir}:\n#{ex}"
    end
  end
end
