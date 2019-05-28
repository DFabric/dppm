require "exec"
require "./service/*"

module Service
  @@init : Systemd.class | OpenRC.class | Nil
  @@initialized = false

  def self.init? : Systemd.class | OpenRC.class | Nil
    if !@@initialized
      init_system = File.basename File.real_path "/sbin/init"
      if init_system == "systemd"
        @@init = Service::Systemd
      elsif File.exists? "/sbin/openrc"
        @@init = Service::OpenRC
      end
      @@initialized = true
    end
    @@init
  end

  def self.init : Systemd.class | OpenRC.class
    init? || raise "unsupported init system"
  end
end
