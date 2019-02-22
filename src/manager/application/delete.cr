require "libcrown"

struct Manager::Application::Delete
  getter app : Prefix::App
  @keep_user_group : Bool
  @preserve_database : Bool

  def initialize(name : String, prefix : Prefix, @keep_user_group : Bool = false, @preserve_database : Bool = false)
    @app = prefix.new_app name

    begin
      if !@preserve_database && (database = @app.database)
        database.check_connection
      end
    rescue ex
      raise Exception.new "either start the database or use the preseve database option:\n#{ex}", ex
    end

    # Checks
    if service = @app.service?
      if service.exists?
        Log.info "a system service is found", @app.name
        service.check_delete
      else
        Log.warn "no system service found", @app.name
      end
    end
  end

  def simulate(io = Log.output)
    io << "task: delete"
    io << "\nname: " << @app.name
    io << "\npackage: " << @app.pkg_file.package
    io << "\nbasedir: " << @app.path
    io << "\nuser: " << @app.owner.user.name
    io << "\ngroup: " << @app.owner.group.name
    @app.service?.try do |service|
      io << "\nservice: " << service.file
    end
    io << '\n'
  end

  def run : Delete
    @app.delete @preserve_database, @keep_user_group
    self
  end
end
