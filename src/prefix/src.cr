require "./base"

struct DPPM::Prefix::Src
  include Base

  protected def initialize(@prefix : Prefix, @name : String, @pkg_file : PkgFile? = nil)
    @path = @prefix.src / @name
  end

  def new_pkg(pkg_name : String, version : String?) : Pkg
    Pkg.new @prefix, pkg_name, version, pkg_file
  end

  # Gets the config key. Yields the block if not found.
  def get_config(key : String, &block)
    config_from_pkg_file key do |config_file, config_key|
      return config_file.get config_key
    end
    deps_with_expr.each_key &.config_from_pkg_file key do |config_file, config_key|
      return config_file.get config_key
    end
    yield
  end

  def each_config_key(&block : String ->)
    internal_each_config_key { |key| yield key }
    deps_with_expr.each_key &.internal_each_config_key { |key| yield key }
  end
end
