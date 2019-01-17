require "./system"

struct Service::OpenRC
  include System
  class_getter type : String = "openrc"

  getter config : Config do
    Config.new @file
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

  def enable(app : Prefix::App)
    File.symlink app.service_file, @file
    File.chmod @file, 0o750
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/sbin/rc-service", {@name, {{action}}}
  end
  {% end %}

  def self.version : String
    output, error = Exec.new "/sbin/openrc", {"-V"}, &.wait
    if output.to_s =~ /([0-9]+\.[0-9]+\.[0-9]+)/
      $1
    else
      raise "can't retrieve the OpenRC version: #{output}#{error}"
    end
  end
end

require "./openrc/*"
