struct Tasks::Install
  def initialize(vars, &@log : String, String, String -> Nil)
    @build = Tasks::Build.new vars, &@log

    # Checks
    Service.check_availability @build.pkg["type"], @build.package, &log

    # Default variables
    unset_vars = Array(String).new
    if @build.pkg["config"]?
      @build.pkg["config"].as_h.each_key do |var|
        unset_vars << var.to_s if !@build.vars[var.to_s]?
      end
    end
    @log.call "WARN", "unset variables", unset_vars.join ", " if !unset_vars.empty?
  end

  def simulate
    @build.simulate
  end

  def run
    @build.run
    # The package to add have the name of the previously built oone
    @build.vars["package"] = @build.vars["name"]
    Dir.cd @build.prefix
    Tasks::Add.new(@build.vars, &@log).run
  end
end
