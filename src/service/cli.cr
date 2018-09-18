module Service::Cli
  def cli_boot(prefix, service, state)
    system.new(service).boot Utils.to_b(state)
  end

  private def cli_get_status(prefix, system)
    if system
      all_status { |service| yield service }
    else
      app_status(prefix) { |service| yield service }
    end
  end

  def cli_status(prefix, system, noboot, norun, services : Array(String))
    print "RUN   " if !norun
    print "BOOT  " if !noboot
    puts "SERVICE\n"
    cli_get_status(prefix, system) do |service|
      if !norun
        if r = service.run?
          STDOUT << r.colorize.green << "  "
        else
          STDOUT << r.colorize.red << ' '
        end
      end
      if !noboot
        if b = service.boot?
          STDOUT << b.colorize.green << "  "
        else
          STDOUT << b.colorize.red << ' '
        end
      end
      STDOUT << service.service
      STDOUT << '\n'
      STDOUT.flush
    end
  end

  def all_status
    system.each do |app|
      yield system.new app
    end
  end

  def app_status(prefix = PREFIX)
    Dir.each_child(Path.new(prefix).app) do |app|
      yield system.new app
    end
  end

  def cli_logs(prefix, service, error)
    log_dir = system.new(service).log_dir
    File.read log_dir + (error ? "error.log" : "output.log")
  end
end
