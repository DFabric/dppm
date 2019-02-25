module Manager::Package::CLI
  extend self

  def delete(no_confirm, config, mirror, source, prefix, package, custom_vars, version, debug = nil)
    Log.info "initializing", "delete"
    task = Delete.new Prefix.new(prefix), package, version

    task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def build(no_confirm, config, mirror, source, prefix, package, custom_vars, version, debug = nil)
    vars = Hash(String, String).new
    Log.info "initializing", "build"
    MainConfig.file = config
    vars["mirror"] = mirror || MainConfig.mirror

    # Update cache
    root_prefix = Prefix.new prefix, true
    root_prefix.update source

    # Create task
    vars.merge! Host.vars
    task = Build.new vars, root_prefix, package, version
    task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def self.query(prefix, config, package, path, **args)
    pkg_file = Prefix.new(prefix).new_pkg(package).pkg_file
    Query.new(pkg_file.any).pkg(path).to_pretty_con
  end
end
