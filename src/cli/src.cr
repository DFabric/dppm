module DPPM::CLI::Src
  extend self

  def info(prefix, source_name, package, path)
    pkg_file = Prefix.new(prefix, source_name: source_name).new_src(package).pkg_file
    CLI.info(pkg_file.any, path).to_pretty_con
  end

  def update(config, prefix, source_name, source_path, no_confirm)
    root_prefix = Prefix.new prefix, source_name: source_name, source_path: source_path
    root_prefix.check
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update no_confirm
  end
end
