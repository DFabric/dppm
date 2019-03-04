module CLI::Src
  extend self

  def query(prefix, package, path, **args)
    pkg_file = Prefix.new(prefix).new_src(package).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def update(config, source, prefix, no_confirm, **args)
    root_prefix = Prefix.new prefix, check: true
    if config
      root_prefix.dppm_config = Prefix::Config.new File.read config
    end
    root_prefix.update source, no_confirm
  end
end
