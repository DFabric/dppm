module CLI::Pkg
  extend self

  def query(prefix, config, package, path, **args)
    pkg_file = Prefix.new(prefix).new_pkg(package).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def clean_unused_packages(no_confirm, prefix, **args)
    Prefix.new(prefix).clean_unused_packages !no_confirm do
      CLI.confirm_prompt
    end
  end

  def delete(no_confirm, prefix, package, version, **args)
    Prefix.new(prefix).new_pkg(package, version).delete !no_confirm do
      CLI.confirm_prompt
    end
  end

  def build(no_confirm, config, source, prefix, package, custom_vars, mirror = nil, version = nil, tag = nil, debug = nil)
    Log.info "initializing", "build"

    # Update cache
    root_prefix = Prefix.new prefix, check: true
    root_prefix.update source
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end

    # Create task
    pkg = Prefix::Pkg.create root_prefix, package, version, tag
    pkg.build mirror: mirror, confirmation: !no_confirm do
      no_confirm || CLI.confirm_prompt
    end
    pkg
  end
end
