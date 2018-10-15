module Manager::Source::CLI
  def self.query(prefix, config, mirror, source, no_confirm, package, path)
    Query.new(Path.new(prefix).src + package).pkg path
  end
end
