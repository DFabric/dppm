module Manager::Source::CLI
  def self.query(prefix, config, mirror, pkgsrc, no_confirm, package, path)
    Query.new(Path.new(prefix).source package).pkg path
  end
end
