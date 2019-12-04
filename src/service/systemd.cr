require "./init_system"

class Service::Systemd
  include InitSystem
  class_getter type : String = "systemd"

  class_getter version : Int32 do
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    output.to_s.lchop("systemd ").partition('\n')[0].partition(' ')[0].to_i
  rescue ex
    raise Error.new "Can't retrieve the systemd version (#{output}#{error})", ex
  end

  def initialize(@name : String)
    @file = if File.exists?(service = "/lib/systemd/system/#{@name}.service")
              Path[service]
            else
              Path["/etc/systemd/system/#{@name}.service"]
            end
    @boot_file = Path["/etc/systemd/system/multi-user.target.wants/#{@name}.service"]
  end

  def self.each(&block : String -> _)
    {"/lib/systemd/system", "/etc/systemd/system"}.each do |service_dir|
      Dir.each_child service_dir do |service|
        if service_name = service.rchop? ".service"
          yield service_name if !service_name.ends_with? '@'
        end
      end
    end
  end

  def run? : Bool
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", "is-active", @name}
  end

  def delete : Bool
    delete_internal
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  def link(service_file : String)
    File.symlink service_file, @file.to_s
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}

  private def config_parse(io : IO)
    Config.from_systemd io
  end

  def config_build(io : IO)
    config.to_systemd io
  end
end

require "./systemd_config"
