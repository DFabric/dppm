struct Tasks::Delete
  @name : String
  @package : String
  @pkgdir : String
  @pkgdir : String
  @service_path : String
  @user : String
  @group : String
  @service = false
  @path : Tasks::Path

  def initialize(vars, @path)
    @name = vars["package"].gsub(':', '_')
    @pkgdir = @path.app + '/' + @name

    stat = File.stat @pkgdir
    @user = Owner.from_id stat.uid, "uid"
    @group = Owner.from_id stat.gid, "gid"

    # Checks
    Tasks.pkg_exists? @pkgdir
    @service_path = Localhost.service.system.new(@name).file
    if File.exists?(@service_path) &&
       File.real_path(@service_path) == "#{@pkgdir}/etc/init/#{Localhost.service.name.downcase}"
      Log.info "a system service is found", @name
      @service = true
    elsif !@name.includes? '_'
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
      str << "\nname: " << @name \
        << "\npackage: " << @package \
        << "\nprefix: " << @path.prefix \
        << "\npkgdir: " << @pkgdir \
        << "\nuser: " << @user \
        << "\ngroup: " << @group \
        << "\nservice: " << @service_path if @service
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
