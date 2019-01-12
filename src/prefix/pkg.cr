require "./program_data"

struct Prefix::Pkg
  include ProgramData
  @version : String?
  @package : String?

  protected def initialize(@prefix : Prefix, @name : String, @pkg_file : PkgFile? = nil)
    @path = @prefix.pkg + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
  end

  def new_app(app_name : String? = nil) : App
    case pkg_file.type
    when .app?
      # Generate a name if none is set
      app_name ||= package + '-' + Random::Secure.hex(8)
      Utils.ascii_alphanumeric_dash? app_name
    else
      # lib and others
      raise "only applications can be added to the system: #{pkg_file.type}"
    end
    App.new @prefix, app_name, pkg_file
  end

  def package : String
    @package ||= @name.split('_').first
  end

  def version : String
    @version ||= @name.split('_').last
  end
end
