module Manager::Source::CLI
  def self.query(prefix, package, path, **args)
    pkg_file = Prefix.new(prefix).new_src(package).pkg_file
    Query.new(pkg_file.any).pkg(path).to_pretty_con
  end
end
