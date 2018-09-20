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
