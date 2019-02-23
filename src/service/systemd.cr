require "./init_system"

struct Service::Systemd
  include InitSystem
  class_getter type : String = "systemd"

  class_getter version : Int32 do
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    output.to_s.split(' ', limit: 3)[1].to_i
  rescue
    raise "can't retrieve the systemd version: #{output}#{error}"
  end

  def initialize(@name : String)
    @file = if File.exists?(service = "/lib/systemd/system/#{@name}.service")
              service
            else
              "/etc/systemd/system/#{@name}.service"
            end
    @boot_file = "/etc/systemd/system/multi-user.target.wants/#{@name}.service"
  end

  getter config : Config do
    if @file && File.exists? @file
      Config.from_systemd File.read(@file)
    else
      Config.new
    end
  end

  def config_build : String
    config.to_systemd
  end

  def self.each(&block : String -> _)
    {"/lib/systemd/system", "/etc/systemd/system"}.each do |service_dir|
      Dir.each_child service_dir do |service|
        if service.ends_with? ".service"
          service_name = service.rchop ".service"
          yield service_name if !service_name.ends_with? '@'
        end
      end
    end
  end

  def run?
    Host.exec? "/bin/systemctl", {"-q", "--no-ask-password", "is-active", @name}
  end

  def delete : Bool
    delete_internal
    Host.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  def link(service_file : String)
    File.symlink service_file, @file
    Host.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Host.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}
end

require "./systemd_config"
