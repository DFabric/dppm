struct Package::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    path : Package::Path,
    vars : Hash(String, String)
  @service_path : String
  @user : String
  @group : String
  @service = false

  def initialize(@vars)
    @path = Path.new vars["prefix"]
    @name = vars["package"].gsub(':', '_')
    @pkgdir = @path.app + '/' + @name

    file = File.info @pkgdir
    @user = Owner.from_id file.owner, "uid"
    @group = Owner.from_id file.group, "gid"

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
      raise "a service is found - root permissions required: " + @name
    end
    Log.info "getting package name", @pkgdir + "/pkg.yml"
    @package = YAML.parse(File.read(@pkgdir + "/pkg.yml"))["package"].as_s
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
    if Localhost.service.writable? && @user.starts_with?(@package) && @user.split('_').last.lowercase_number?
      Owner.del_all @user
      Log.info "user and group deleted", @user
    end
    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
  end
end
