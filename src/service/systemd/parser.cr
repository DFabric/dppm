require "ini"

struct Service::Systemd::Config
  def self.parse(data : String)
    new INI.parse(data)
  end
end
