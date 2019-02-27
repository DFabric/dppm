module Manager::Package::CLI
  extend self

  def delete(no_confirm, prefix, package, version, **args)
    Prefix.new(prefix).new_pkg(package, version).delete !no_confirm do
      Manager.cli_confirm
    end
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
    pkg = Prefix::Pkg.create root_prefix, package, version, vars["tag"]?
    pkg.build vars: vars, confirmation: !no_confirm do
      no_confirm || Manager.cli_confirm
    end
    pkg
  end

  def self.query(prefix, config, package, path, **args)
    pkg_file = Prefix.new(prefix).new_pkg(package).pkg_file
    Query.new(pkg_file.any).pkg(path).to_pretty_con
  end
end
