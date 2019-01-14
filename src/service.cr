require "exec"
require "./logger"
require "./prefix"
require "./service/*"

module Service
  ROOT_PATH = "/etc/init/"

  def self.exec?(command : String, args : Array(String) | Tuple) : Bool
    success = false
    Exec.new command, args, output: Log.output, error: Log.error do |process|
      success = process.wait.success?
    end
    return success
  end
end
