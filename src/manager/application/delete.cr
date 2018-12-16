require "libcrown"

struct Manager::Application::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    pkg_file : PkgFile,
    service : Service::Systemd | Service::OpenRC | Nil
  @keep_user_group : Bool
  @uid : UInt32
  @gid : UInt32
  @user : String
  @group : String

  def initialize(@name : String, @prefix : String, @keep_user_group : Bool = false)
    @path = Path.new @prefix
    @pkgdir = @path.app + @name

    file = File.info @pkgdir
    @uid = file.owner
    @gid = file.group
    libcrown = Libcrown.new nil
    @user = libcrown.users[@uid].name
    @group = libcrown.groups[@gid].name

    # Checks
    @pkg_file = PkgFile.new @pkgdir
    @package = pkg_file.package
    if service = Host.service?.try &.new @name
      if service.exists? && service.is_app?(@pkgdir)
        Log.info "a system service is found", @name
        service.check_delete
        @service = service
      else
        Log.warn "no system service found", @name
        @service = nil
      end
    end
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

    if !@keep_user_group && Process.root?
      libcrown = Libcrown.new
      libcrown.del_user @uid if @user.starts_with? '_' + @name
      libcrown.del_group @gid if @group.starts_with? '_' + @name
      libcrown.write
    end

    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
    self
  end
end
