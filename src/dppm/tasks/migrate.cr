require "semantic_compare"

struct Tasks::Migrate
  @old_pkgdir : String
  @old_version : String
  @package : String

  def initialize(vars, &log : String, String, String -> Nil)
    @log = log
    @package = vars["package"]
    vars["name"] = @package + ".new"
    @old_pkgdir = vars["prefix"] + '/' + @package
    @old_version = Pkg.new(@package).current_version
    Tasks.pkg_exists? @old_pkgdir

    # Init
    @build = Tasks::Build.new vars, &@log
    Tasks.checks @build.pkg["type"], @build.package, &log
    if SemanticCompare.version @old_version, '<' + @build.version
      @log.call "INFO", "upgrading from " + @old_version, @build.version
    elsif SemanticCompare.version @old_version, '>' + @build.version
      @log.call "WARN", "downgraging from " + @old_version, @build.version
    elsif SemanticCompare.version @old_version, @build.version
      @log.call "WARN", "use of `clone` task` recommended instead of `migrate`", "using the same version " + @old_version
    else
      raise "can't compare the semantic versions " + @old_version + "with " + @build.version
    end
    @log.call "INFO", "temporary build name for " + @package, vars["name"]
  end

  def simulate
    @build.simulate
  end

  def run
    @build.run
    ["srv", "etc"].each do |dir|
      if Dir.exists? @old_pkgdir + '/' + dir
        FileUtils.rm_rf @build.pkgdir + '/' + dir
        FileUtils.cp_r @old_pkgdir + '/' + dir, @build.pkgdir + '/' + dir
      end
    end
    HOST.service.run @package, false

    # Change the name of the package to the original
    File.rename @old_pkgdir, @build.prefix + '/' + @package + '-' + @old_version
    File.rename @build.pkgdir, @old_pkgdir
    @build.vars["package"] = @package

    Tasks::Add.new(@build.vars, &@log).run
  end
end
