# Global constant variables
CONFIG_FILE     = "./config.ini"
PREFIX          = (::System::Owner.root? ? "/opt" : ENV["HOME"]) + "/dppm"
LOG_OUTPUT_PATH = "log/output.log"
LOG_ERROR_PATH  = "log/error.log"

struct Path
  getter app : String
  getter pkg : String
  getter src : String
  getter prefix : String

  def initialize(@prefix, create = false)
    @app = @prefix + "/app"
    @pkg = @prefix + "/pkg"
    @src = @prefix + "/src"
    FileUtils.mkdir_p({@app, @pkg}) if create
  end
end
