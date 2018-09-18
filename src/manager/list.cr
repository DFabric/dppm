struct Manager::List
  @path : Path

  def initialize(prefix)
    @path = Path.new prefix
  end

  def all
    puts "applications:"
    app { |app| puts app }
    puts "\npackages:"
    pkg { |pkg| puts pkg }
    puts "\nsource:"
    src { |src| puts src }
  end

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
