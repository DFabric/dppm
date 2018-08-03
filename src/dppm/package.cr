module Package
  extend self

  def confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end

  def pkg_exists?(dir)
    raise "doesn't exist: #{dir}/pkg.yml" if !File.exists? dir + "/pkg.yml"
  end

  struct Path
    getter app : String
    getter pkg : String
    getter src : String
    getter prefix : String

    def initialize(@prefix)
      @app = @prefix + "/app"
      @pkg = @prefix + "/pkg"
      FileUtils.mkdir_p [@app, @pkg]
      @src = @prefix + "/src"
    end
  end
end
