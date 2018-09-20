struct Manager::List
  getter path : Path

  def initialize(prefix)
    @path = Path.new prefix
  end

  def self.cli_all(prefix, config, mirror, pkgsrc, no_confirm)
    list = new prefix
    puts "applications:"
    list.app { |app| puts app }
    puts "\npackages:"
    list.pkg { |pkg| puts pkg }
    puts "\nsources:"
    list.src { |src| puts src }
  end

  {% for i in %w(app pkg src) %}
  def self.cli_{{i.id}}(prefix, config, mirror, pkgsrc, no_confirm)
    new(prefix).{{i.id}} { |i| puts i }
  end
  {% end %}

  def app
    Dir.each_child(@path.app) { |app| yield app }
  end

  def pkg
    Dir.each_child(@path.pkg) { |pkg| yield pkg }
  end

  def src
    Dir.each_child(@path.src) { |src| yield src if src[0].ascii_lowercase? }
  end
end
