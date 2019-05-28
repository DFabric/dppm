require "./init_system"

class Service::OpenRC
  include InitSystem
  class_getter type : String = "openrc"

  class_getter version : String do
    output, error = Exec.new "/sbin/openrc", {"-V"}, &.wait
    output.to_s =~ /([0-9]+\.[0-9]+\.[0-9]+)/
    $1.not_nil!
  rescue
    raise "can't retrieve the OpenRC version: #{output}#{error}"
  end

  def initialize(@name : String)
    @file = Path["/etc/init.d", @name]
    @boot_file = Path["/etc/runlevels/default", @name]
  end

  getter config : Config do
    if @file && File.exists? @file.to_s
      Config.from_openrc File.read(@file.to_s)
    else
      Config.new
    end
  end

  def config_build : String
    config.to_openrc
  end

  def self.each(&block : String -> _)
    Dir.each_child "/etc/init.d" do |service|
      yield service
    end
  end

  def run? : Bool
    Host.exec? "/sbin/rc-service", {@name, "status"}
  end

  def delete
    delete_internal
  end

  def link(service_file : String)
    File.symlink service_file, @file.to_s
    File.chmod @file.to_s, 0o750
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Host.exec? "/sbin/rc-service", {@name, {{action}}}
  end
  {% end %}
end

require "./openrc_config"
