struct Service::Systemd::System < Service::System
  getter service : String
  getter file : String
  getter boot : String
  getter init_path = "/etc/init/systemd"

  def initialize(@service)
    @file = if File.exists?(conf = "/lib/systemd/system/#{@service}.service")
              conf
            else
              "/etc/systemd/system/#{@service}.service"
            end
    @boot = "/etc/systemd/system/multi-user.target.wants/#{@service}.service"
  end

  def self.each
    Dir["/lib/systemd/system/*.service", "/etc/systemd/system/*.service"].each do |service|
      yield File.basename(service)[0..-9]
    end
  end

  def run?
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "is-active", @service]).success?
  end

  def delete
    stop
    boot false if boot?
    File.delete @file
    Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"]
  end

  def link(src)
    File.symlink src + @init_path, @file
    Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"]
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", {{action}}, @service]).success?
  end
  {% end %}
end
