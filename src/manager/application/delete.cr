require "libcrown"

struct Manager::Application::Delete
  getter app : Prefix::App
  @keep_user_group : Bool
  @uid : UInt32
  @gid : UInt32
  @user : String
  @group : String

  def initialize(@name : String, prefix : Prefix, @keep_user_group : Bool = false)
    @app = prefix.new_app @name

    file = File.info @app.path
    @uid = file.owner
    @gid = file.group
    libcrown = Libcrown.new nil
    @user = libcrown.users[@uid].name
    @group = libcrown.groups[@gid].name

    # Checks
    @app.service?.try do |service|
      if service.exists?
        Log.info "a system service is found", @name
        service.check_delete
      else
        Log.warn "no system service found", @name
      end
    end
  end

  def simulate
    String.build do |str|
      str << "\nname: " << @name
      str << "\npackage: " << @app.pkg_file.package
      str << "\nbasedir: " << @app.path
      str << "\nuser: " << @user
      str << "\ngroup: " << @group
      @app.service.try do |service|
        str << "\nservice: " << service.file
      end
    end
  end

  def run
    Log.info "deleting", @app.path
    @app.service?.try do |service|
      Log.info "deleting system service", service.name
      service.delete
    end

    if !@keep_user_group && Process.root?
      libcrown = Libcrown.new
      libcrown.del_user @uid if @user.starts_with? '_' + @name
      libcrown.del_group @gid if @group.starts_with? '_' + @name
      libcrown.write
    end

    FileUtils.rm_r @app.path
    Log.info "delete completed", @app.path
    self
  end
end
