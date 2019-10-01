require "exec"
require "./service/*"

module Service
  extend self

  @@init : Systemd.class | OpenRC.class | Nil
  @@initialized = false

  def init? : Systemd.class | OpenRC.class | Nil
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

  def init : Systemd.class | OpenRC.class
    init? || raise "Unsupported init system"
  end

  def exec?(command : String, args : Array(String) | Tuple) : Bool
    success = false
    Exec.new command, args, output: DPPM::Logger.output, error: DPPM::Logger.error do |process|
      success = process.wait.success?
    end
    success
  end
end
