require "./init_system"

class Service::Systemd
  include InitSystem
  class_getter type : String = "systemd"

  class_getter version : Int32 do
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    output.to_s.lchop("systemd ").partition('\n')[0].partition(' ')[0].to_i
  rescue ex
    raise "can't retrieve the systemd version (#{output}#{error}): #{ex}"
  end

  def initialize(@name : String)
    @file = if File.exists?(service = "/lib/systemd/system/#{@name}.service")
              Path[service]
            else
              Path["/etc/systemd/system/#{@name}.service"]
            end
    @boot_file = Path["/etc/systemd/system/multi-user.target.wants/#{@name}.service"]
  end

  getter config : Config do
    if @file && File.exists? @file.to_s
      Config.from_systemd File.read(@file.to_s)
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
        if service_name = service.rchop? ".service"
          yield service_name if !service_name.ends_with? '@'
        end
      end
    end
  end

  def run? : Bool
    Host.exec? "/bin/systemctl", {"-q", "--no-ask-password", "is-active", @name}
  end

  def delete : Bool
    delete_internal
    Host.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  def link(service_file : String)
    File.symlink service_file, @file.to_s
    Host.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Host.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}
end

require "./systemd_config"
