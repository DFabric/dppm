require "exec"
require "./prefix"
require "./service/cli"

module Service
  def self.exec?(command : String, args : Array(String) | Tuple) : Bool
    success = false
    Exec.new command, args, output: Log.output, error: Log.error do |process|
      success = process.wait.success?
    end
    return success
  end

  @@init : Systemd.class | OpenRC.class | Nil
  @@supported : Bool?

  def self.init? : Systemd.class | OpenRC.class | Nil
    if !@@supported.is_a? Bool
      init_system = File.basename File.real_path "/sbin/init"
      @@supported = if init_system == "systemd"
                      @@init = Service::Systemd
                      true
                    elsif File.exists? "/sbin/openrc"
                      @@init = Service::OpenRC
                      true
                    else
                      false
                    end
    end
    @@init
  end

  def self.init : Systemd.class | OpenRC.class
    if init = init?
      init
    else
      raise "unsupported init system"
    end
  end
end
