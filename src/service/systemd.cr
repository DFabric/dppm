require "./system"

struct Service::Systemd
  include System
  class_getter type : String = "systemd"

  getter config : Config do
    Config.new @file
  end

  def initialize(@name : String)
    @file = if File.exists?(service = "/lib/systemd/system/#{@name}.service")
              service
            else
              "/etc/systemd/system/#{@name}.service"
            end
    @boot_file = "/etc/systemd/system/multi-user.target.wants/#{@name}.service"
  end

  def self.each
    Dir["/lib/systemd/system/*.service", "/etc/systemd/system/*.service"].each do |service|
      yield File.basename(service)[0..-9]
    end
  end

  def run?
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", "is-active", @name}
  end

  def delete : Bool
    delete_internal
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  def enable(app : Prefix::App) : Bool
    File.symlink app.service_file, @file
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}

  def self.version : Int32
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    if output.to_s =~ / ([0-9]+)\n/
      $1.to_i
    else
      raise "can't retrieve the systemd version: #{output}#{error}"
    end
  end
end

require "./systemd/*"
