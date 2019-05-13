module DPPM::CLI::Src
  extend self

  def query(prefix, source_name, package, path, **args)
    pkg_file = Prefix.new(prefix, source_name: source_name).new_src(package).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def update(config, prefix, source_name, source_path, no_confirm, **args)
    root_prefix = Prefix.new prefix, source_name: source_name, source_path: source_path
    root_prefix.check
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update no_confirm
  end
end
