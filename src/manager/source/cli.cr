module Manager::Source::CLI
  def self.query(prefix, config, mirror, pkgsrc, no_confirm, package, path)
    Query.new(Path.new(prefix).src, package).pkg path
  end
end
