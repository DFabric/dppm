require "semantic_compare"

struct Tasks::Migrate
  @old_pkgdir : String
  @old_version : String
  @package : String

  def initialize(vars, &@log : String, String, String -> Nil)
    @package = vars["package"]
    @old_pkgdir = vars["prefix"] + '/' + @package
    @old_version = Pkg.new(@package).version
    Tasks.pkg_exists? @old_pkgdir

    @add = Tasks::Add.new(@build.vars, &@log)

    Localhost.service.check_availability @build.pkg["type"], @build.package, &log
    # begin
    #   if SemanticCompare.version @old_version, '<' + @build.version
    #     @log.call "INFO", "upgrading from " + @old_version, @build.version
    #   elsif SemanticCompare.version @old_version, '>' + @build.version
    #     @log.call "WARN", "downgraging from " + @old_version, @build.version
    #   elsif SemanticCompare.version @old_version, @build.version
    #     @log.call "WARN", "use of the `clone` task recommended instead of `migrate`", "using the same version " + @old_version
    #   else
    #     raise "error"
    #   end
    # rescue
    #   @log.call "WARN", "can't compare the semantic versions ", @old_version + " - " + @build.version
    # end
    @log.call "INFO", "temporary build name for " + @package, vars["name"]
  end

  def simulate
    @build.simulate
  end

  def run
    @build.run

    Localhost.service.system.new(@package).run false

    # Change the name of the package to the original

    Tasks::Add.new(@build.vars, &@log).run
  end
end
