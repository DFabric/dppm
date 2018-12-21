require "./base"

struct Prefix::Src
  include Base

  protected def initialize(@prefix : Prefix, @name : String)
    @path = @prefix.src + @name + '/'
  end

  def new_pkg(pkg_name : String) : Pkg
    Pkg.new @prefix, pkg_name, pkg_file
  end
end
