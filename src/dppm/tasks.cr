module Tasks
  extend self

  def init(task, package, vars, &log : String, String, String -> Nil)
    log.call "INFO", "initializing", task
    vars.merge! HOST.vars
    vars["package"] = package
    vars["prefix"] = Dir.current if !vars["prefix"]?
    Dir.cd vars["prefix"]

    # Update cache if older than 2 days
    if !(File.exists?(CACHE) || File.symlink?(CACHE)) ||
       Time.utc_now.to_s("%Y%m%d").to_i - File.lstat(CACHE).ctime.to_s("%Y%m%d").to_i > 2
      Command.cache vars["pkgsrc"], &log
    end

    case task
    when "a", "add"   then Add.new vars, &log
    when "b", "build" then Build.new vars, &log
      # Install regroup build + add
    when "i", "install" then Install.new vars, &log
    when "m", "migrate" then Migrate.new vars, &log
    when "d", "delete"  then Delete.new vars, &log
    else
      raise "task not supported: " + task
    end
  end

  def confirm(task)
    puts "\nOk? [N/y]"
    gets =~ /[Yy]/ ? true : puts "cancelled: " + task
  end

  def pkg_exists?(dir)
    raise "doesn't exist: " + dir + "/pkg.yml" if !File.exists? dir + "/pkg.yml"
  end
end
