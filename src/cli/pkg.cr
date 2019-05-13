module DPPM::CLI::Pkg
  extend self

  def query(prefix, source_name, config, package, path, **args)
    pkg_file = Prefix.new(prefix, source_name: source_name).new_pkg(package).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def clean_unused_packages(no_confirm, prefix, source_name, **args)
    Prefix.new(prefix, source_name: source_name).clean_unused_packages !no_confirm do
      CLI.confirm_prompt
    end
  end

  def delete(no_confirm, prefix, source_name, package, version, **args)
    Prefix.new(prefix, source_name: source_name).new_pkg(package, version).delete !no_confirm do
      CLI.confirm_prompt
    end
  end

  def build(no_confirm, config, prefix, source_name, source_path, package, custom_vars, version = nil, tag = nil, debug = nil)
    Log.info "initializing", "build"

    # Update cache
    root_prefix = Prefix.new prefix, source_name: source_name, source_path: source_path
    root_prefix.check
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update

    # Create task
    pkg = Prefix::Pkg.create root_prefix, package, version, tag
    pkg.build confirmation: !no_confirm do
      no_confirm || CLI.confirm_prompt
    end
    pkg
  end
end
