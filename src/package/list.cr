struct Package::List
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
    puts "\nservices:\t\trun | boot"
    services_cli
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

  def services
    Dir.each_child(@path.app) do |app|
      service = ::System::Host.service.system.new app
      yield service if service.exists?
    end
  end

  def services_cli
    services do |service|
      puts service.service + "\t#{(r = service.run?) ? r.colorize.green : r.colorize.red} #{(b = service.boot?) ? b.colorize.green : b.colorize.red}"
    end
  end
end
