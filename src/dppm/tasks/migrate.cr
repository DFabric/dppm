require "semantic_compare"

struct Tasks::Migrate
  @old_pkgdir : String
  @old_version : String
  @package : String

  def initialize(vars)
    @package = vars["package"]
    @old_pkgdir = vars["prefix"] + '/' + @package
    @old_version = Pkg.new(@package).version
    Tasks.pkg_exists? @old_pkgdir

    @add = Tasks::Add.new(@build.vars)

    Localhost.service.check_availability @build.pkg["type"], @build.package
    # begin
    #   if SemanticCompare.version @old_version, '<' + @build.version
    #     Log.info "upgrading from " + @old_version, @build.version
    #   elsif SemanticCompare.version @old_version, '>' + @build.version
    #     Log.warn "downgraging from " + @old_version, @build.version
    #   elsif SemanticCompare.version @old_version, @build.version
    #     Log.warn "use of the `clone` task recommended instead of `migrate`", "using the same version " + @old_version
    #   else
    #     raise "error"
    #   end
    # rescue
    #   @log.call "WARN", "can't compare the semantic versions ", @old_version + " - " + @build.version
    # end
    Log.info "temporary build name for " + @package, vars["name"]
  end

  def simulate
    @build.simulate
  end

  def run
    @build.run

    Localhost.service.system.new(@package).run false

    # Change the name of the package to the original

    Tasks::Add.new(@build.vars).run
  end
end
