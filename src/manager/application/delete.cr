struct Manager::Application::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    pkg : YAML::Any,
    service : Service::Systemd | Service::OpenRC | Nil
  @keep_user_group : Bool
  @user : String
  @group : String

  def initialize(@name, @prefix, @keep_user_group : Bool = false)
    @path = Path.new @prefix
    @pkgdir = @path.application @name

    file = File.info @pkgdir
    @user = ::System::Owner.to_user file.owner
    @group = ::System::Owner.to_group file.group

    # Checks
    Manager.pkg_exists? @pkgdir
    if service = ::System::Host.service?.try &.new @name
      if service.exists? && (File.real_path(service.file) == @pkgdir + service.init_path)
        "/etc/init/" + service.type.downcase
        Log.info "a system service is found", @name
        @service = service
      else
        Log.warn "no system service found", @name
        @service = nil
      end
    end
    if @service && !::System::Owner.root?
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
      str << "\nservice: " << @service.try &.file if @service
    end
  end

  def run
    Log.info "deleting", @pkgdir
    @service.try &.delete

    if !@keep_user_group && ::System::Owner.root?
      ::System::Owner.del_user @user if @user.starts_with? '_' + @name
      ::System::Owner.del_group @group if @group.starts_with? '_' + @name
    end

    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
  end
end
