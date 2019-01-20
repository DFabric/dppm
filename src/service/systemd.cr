require "./init_system"

struct Service::Systemd
  include InitSystem
  class_getter type : String = "systemd"

  class_getter version : Int32 do
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    output.to_s.lines[0].lstrip("systemd ").to_i
  rescue
    raise "can't retrieve the systemd version: #{output}#{error}"
  end

  getter config : Config do
    Config.read @file
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

  def link(service_file : String)
    File.symlink service_file, @file
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}
end

require "./systemd_config"
