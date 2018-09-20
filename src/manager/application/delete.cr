struct Manager::Application::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    pkg : YAML::Any,
    service : Service::Systemd::System | Service::OpenRC::System
  @has_service = false
  @keep_user_group : Bool
  @user : String
  @group : String

  def initialize(@name, @prefix, @keep_user_group : Bool = false)
    @path = Path.new @prefix
    @pkgdir = @path.app + '/' + @name

    file = File.info @pkgdir
    @user = ::System::Owner.to_user file.owner
    @group = ::System::Owner.to_group file.group

    @service = ::System::Host.service.system.new @name

    # Checks
    Manager.pkg_exists? @pkgdir
    if @service.exists? && (File.real_path(@service.file) == @pkgdir + @service.init_path)
      "/etc/init/" + ::System::Host.service.name.downcase
      Log.info "a system service is found", @name
      @has_service = true
    else
      Log.warn "no system service found", @name
    end
    if !::System::Owner.root? && @has_service
      raise "root permissions required to delete the service: " + @name
    end
    Log.info "getting package name", @pkgdir + "/pkg.yml"
    @pkg = YAML.parse(File.read(@pkgdir + "/pkg.yml"))
    @package = @pkg["package"].as_s
  end

  def simulate
    String.build do |str|
      str << "\nname: " << @name
      str << "\npackage: " << @package
      str << "\npkgdir: " << @pkgdir
      str << "\nuser: " << @user
      str << "\ngroup: " << @group
      str << "\nservice: " << @service.file if @has_service
    end
  end

  def run
    Log.info "deleting", @pkgdir
    @service.delete @name if @has_service

    if !@keep_user_group && ::System::Owner.root?
      ::System::Owner.del_user @user if @user.starts_with? '_' + @name
      ::System::Owner.del_group @group if @group.starts_with? '_' + @name
    end

    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
  end
end
