struct Path
  getter app : String
  getter pkg : String
  getter src : String
  getter prefix : String

  def initialize(@prefix : String, create : Bool = false)
    @app = @prefix + "/app/"
    @pkg = @prefix + "/pkg/"
    @src = @prefix + "/src/"
    FileUtils.mkdir_p({@app, @pkg}) if create
  end

  def application_log(name : String, error : Bool = false)
    @app + name + '/' + (error ? Service::LOG_ERROR_PATH : Service::LOG_OUTPUT_PATH)
  end

  # Creates a PATH environment variable
  def self.env_var(pkgdir : String) : String
    String.build do |str|
      Dir.each_child(pkgdir + "/lib") do |library|
        str << pkgdir << "/lib/" << library << "/bin:"
      end
    end.rchop
  end
end
