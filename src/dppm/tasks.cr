module Tasks
  extend self

  def init(task, package, vars, &log : String, String, String -> Nil)
    log.call "INFO", "initializing", task
    vars.merge! HOST.vars
    vars["package"] = package
    vars["prefix"] = Dir.current if !vars["prefix"]?
    Dir.cd vars["prefix"]

    # Update cache if older than 2 days
    if !(File.exists?(CACHE[0..-2]) || File.symlink?(CACHE[0..-2])) ||
       Time.utc_now.to_s("%Y%m%d").to_i - File.lstat(CACHE[0..-2]).ctime.to_s("%Y%m%d").to_i > 2
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

  def checks(pkgtype, package, &log : String, String, String -> Nil)
    if HOST.service.writable?
      service = HOST.service.file package
      raise "system service already exist: " + service if File.exists? service
    else
      log.call "WARN", "system service unavailable", "root execution needed"
    end
    raise "only applications can be added to the system" if pkgtype != "app"
  end
end
