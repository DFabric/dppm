require "./init_system"

class Service::OpenRC
  include InitSystem
  class_getter type : String = "openrc"

  class_getter version : String do
    output, error = Exec.new "/sbin/openrc", {"-V"}, &.wait
    output.to_s.rpartition(' ')[-1].rpartition('.')[-1]
  rescue ex
    raise Error.new "Can't retrieve the OpenRC version (#{output}#{error})", ex
  end

  def initialize(@name : String)
    @file = Path["/etc/init.d", @name]
    @boot_file = Path["/etc/runlevels/default", @name]
  end

  def self.each(&block : String -> _)
    Dir.each_child "/etc/init.d" do |service|
      yield service
    end
  end

  def run? : Bool
    Service.exec? "/sbin/rc-service", {@name, "status"}
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
    Service.exec? "/sbin/rc-service", {@name, {{action}}}
  end
  {% end %}

  private def config_parse(io : IO)
    Config.from_openrc io
  end

  def config_build(io : IO)
    config.to_openrc io
  end
end

require "./openrc_config"
