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
    init? || raise "Unsupported init system"
  end

  def self.exec?(command : String, args : Array(String) | Tuple) : Bool
    success = false
    Exec.new command, args, output: DPPM::Log.output, error: DPPM::Log.error do |process|
      success = process.wait.success?
    end
    return success
  end
end
