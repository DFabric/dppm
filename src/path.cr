struct Path
  getter app : String
  getter pkg : String
  getter src : String
  getter prefix : String

  def initialize(@prefix : String, create = false)
    @app = @prefix + "/app"
    @pkg = @prefix + "/pkg"
    @src = @prefix + "/src"
    FileUtils.mkdir_p({@app, @pkg}) if create
  end

  def application(name : String) : String
    @app + '/' + name
  end

  def application_log(name : String, error = false)
    application(name) + '/' + (error ? LOG_ERROR_PATH : LOG_OUTPUT_PATH)
  end

  def package(name : String) : String
    @pkg + '/' + name
  end

  def source(name : String) : String
    @src + '/' + name
  end

  # Creates a PATH environment variable
  def self.env_var(pkgdir : String) : String
    String.build do |str|
      Dir.each_child(pkgdir + "/lib") do |library|
        str << pkgdir + "/lib/#{library}/bin:"
      end
    end.rchop
  end
end
