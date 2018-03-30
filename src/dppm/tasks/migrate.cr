require "semantic_compare"

struct Tasks::Migrate
  @old_pkgdir : String
  @old_version : String
  @package : String

  def initialize(vars, &@log : String, String, String -> Nil)
    @package = vars["package"]
    vars["name"] = @package + ".new"
    @old_pkgdir = vars["prefix"] + '/' + @package
    @old_version = Pkg.new(@package).version
    Tasks.pkg_exists? @old_pkgdir

    # Init
    @build = Tasks::Build.new vars, &@log
    Localhost.service.check_availability @build.pkg["type"], @build.package, &log
    begin
      if SemanticCompare.version @old_version, '<' + @build.version
        @log.call "INFO", "upgrading from " + @old_version, @build.version
      elsif SemanticCompare.version @old_version, '>' + @build.version
        @log.call "WARN", "downgraging from " + @old_version, @build.version
      elsif SemanticCompare.version @old_version, @build.version
        @log.call "WARN", "use of the `clone` task recommended instead of `migrate`", "using the same version " + @old_version
      else
        raise "error"
      end
    rescue
      @log.call "WARN", "can't compare the semantic versions ", @old_version + " - " + @build.version
    end
    @log.call "INFO", "temporary build name for " + @package, vars["name"]
  end

  def simulate
    @build.simulate
  end

  def run
    @build.run
    # Keep the data and configuration
    ["srv", "etc"].each do |dir|
      if Dir.exists? @old_pkgdir + dir
        Dir[@build.pkgdir + dir + "/*"].each { |entry| FileUtils.rm_r entry }
        Dir[@old_pkgdir + dir + "/*"].each do |entry|
          FileUtils.cp_r @old_pkgdir + dir + entry, @build.pkgdir + dir + entry
        end
      end
    end
    Localhost.service.system.new(@package).run false

    # Change the name of the package to the original
    File.rename @old_pkgdir, @build.prefix + '/' + @package + '-' + @old_version
    File.rename @build.pkgdir, @old_pkgdir
    @build.vars["package"] = @package

    Tasks::Add.new(@build.vars, &@log).run
  end
end
