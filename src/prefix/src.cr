require "./base"

struct Prefix::Src
  include Base

  protected def initialize(@prefix : Prefix, @name : String, @pkg_file : PkgFile? = nil)
    @path = @prefix.src + @name + '/'
  end

  def new_pkg(pkg_name : String, version : String?) : Pkg
    Pkg.new @prefix, pkg_name, version, pkg_file
  end
end
