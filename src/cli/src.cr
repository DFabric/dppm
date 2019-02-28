module CLI::Src
  extend self

  def query(prefix, package, path, **args)
    pkg_file = Prefix.new(prefix).new_src(package).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def update(config, source, prefix, no_confirm, **args)
    prefix = Prefix.new prefix, create: true
    if !source
      Prefix::Config.file = config
    end
    prefix.update source, no_confirm
  end
end
