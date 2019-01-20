require "./init_system"

struct Service::OpenRC
  include InitSystem
  class_getter type : String = "openrc"

  class_getter version : String do
    output, error = Exec.new "/sbin/openrc", {"-V"}, &.wait
    output.to_s =~ /([0-9]+\.[0-9]+\.[0-9]+)/
    $1.not_nil!
  rescue
    raise "can't retrieve the OpenRC version: #{output}#{error}"
  end

  getter config : Config do
    Config.read @file
  end

  def initialize(@name : String)
    @file = "/etc/init.d/" + @name
    @boot_file = "/etc/runlevels/default/" + @name
  end

  def self.each
    Dir.new("/etc/init.d").each do |service|
      yield service
    end
  end

  def run?
    Service.exec? "/sbin/rc-service", {@name, "status"}
  end

  def delete
    delete_internal
  end

  def link(service_file : String)
    File.symlink service_file, @file
    File.chmod @file, 0o750
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/sbin/rc-service", {@name, {{action}}}
  end
  {% end %}
end

require "./openrc_config"
