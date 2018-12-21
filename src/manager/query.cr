struct Manager::Query
  @pkg_file : Prefix::PkgFile

  def initialize(@pkg_file : Prefix::PkgFile)
  end

  def pkg(path : String)
    case path
    when "."
      @pkg_file.any.to_pretty_con
    when "version"
      @pkg_file.package_version
    else
      @pkg_file.any[Utils.to_array path].to_pretty_con
    end
  end
end
