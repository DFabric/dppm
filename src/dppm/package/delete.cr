struct Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    path : Package::Path,
    vars : Hash(String, String),
    pkg : YAML::Any
  @service_path : String
  @user : String
  @group : String
  @service = false

  def initialize(@vars)
    @path = Path.new vars["prefix"]
    @name = vars["package"].gsub(':', '_')
    @pkgdir = @path.app + '/' + @name

    file = File.info @pkgdir
    @user = Owner.to_user file.owner
    @group = Owner.to_group file.group

    # Checks
    Package.pkg_exists? @pkgdir
    @service_path = Localhost.service.system.new(@name).file
    if File.exists?(@service_path) &&
       File.real_path(@service_path) == "#{@pkgdir}/etc/init/#{Localhost.service.name.downcase}"
      Log.info "a system service is found", @name
      @service = true
    else
      Log.warn "no system service found", @name
    end
    if !Localhost.service.writable? && @service
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
      str << "\nprefix: " << @path.prefix
      str << "\npkgdir: " << @pkgdir
      str << "\nuser: " << @user
      str << "\ngroup: " << @group
      str << "\nservice: " << @service_path if @service
    end
  end

  def run
    Log.info "deleting", @pkgdir
    Localhost.service.delete @name if @service
    if Localhost.service.writable? && Owner.generated? @user, @package
      Owner.del_user @user
    end
    if Localhost.service.writable? && Owner.generated? @group, @package
      Owner.del_group @group
    end

    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
  end
end
