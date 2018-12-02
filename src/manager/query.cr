require "./pkg_file"

struct Manager::Query
  @pkg_file : PkgFile

  def initialize(pkgdir)
    @pkg_file = PkgFile.new pkgdir
  end

  def pkg(path)
    case path
    when "."
      @pkg_file.any.to_pretty_con
    when "version"
      File.basename(File.dirname(File.real_path(@pkg_file.path))).split('_').last
    else
      @pkg_file.any[Utils.to_array path].to_pretty_con
    end
  end
end
