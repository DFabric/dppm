require "./program_data"

struct Prefix::Pkg
  include ProgramData

  protected def initialize(@prefix : Prefix, @name : String, @pkg_file : PkgFile? = nil)
    @path = @prefix.pkg + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
  end

  def new_app(app_name : String) : App
    App.new @prefix, app_name, pkg_file
  end
end
