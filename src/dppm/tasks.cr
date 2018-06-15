module Tasks
  extend self

  def init(task, package, vars)
    Log.info "initializing", task
    vars.merge! Localhost.vars
    vars["package"] = package
    path = Path.new vars["prefix"]?
    vars["prefix"] = path.prefix

    # Update cache
    Command.cache vars["pkgsrc"], path.src

    case task
    when "a", "add"   then Add.new vars, path
    when "b", "build" then Build.new vars, path
      # Install regroup build + add
      # when "m", "migrate" then Migrate.new vars
    when "d", "delete" then Delete.new vars, path
    else
      raise "task not supported: " + task
    end
  end

  def confirm(task)
    puts "\nContinue? [N/y]"
    gets =~ /[Yy]/ ? true : puts "cancelled: " + task
  end

  def pkg_exists?(dir)
    raise "doesn't exist: #{dir}/pkg.yml" if !File.exists? dir + "/pkg.yml"
  end

  struct Path
    getter app : String
    getter pkg : String
    getter src : String
    getter prefix : String

    def initialize(prefix = "/opt/dppm")
      @prefix = if prefix.nil?
                  "/opt/dppm"
                else
                  prefix
                end
      @app = @prefix + "/app"
      @pkg = @prefix + "/pkg"
      FileUtils.mkdir_p [@app, @pkg]
      @src = @prefix + "/src"
    end
  end
end
