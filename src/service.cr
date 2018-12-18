require "exec"
require "./path"
require "./service/*"

module Service
  ROOT_PATH       = "/etc/init/"
  LOG_OUTPUT_PATH = "log/output.log"
  LOG_ERROR_PATH  = "log/error.log"

  def self.exec?(command : String, args : Array(String) | Tuple) : Bool
    success = false
    Exec.new command, args, output: Log.output, error: Log.error do |process|
      success = process.wait.success?
    end
    return success
  end
end
