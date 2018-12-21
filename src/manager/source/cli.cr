module Manager::Source::CLI
  def self.query(prefix, config, mirror, source, no_confirm, package, path)
    pkg_file = Prefix.new(prefix).new_src(package).pkg_file
    Query.new(pkg_file).pkg path
  end
end
