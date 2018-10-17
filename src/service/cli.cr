module Service::CLI
  extend self

  def boot(prefix : String, service : String, state : String)
    ::System::Host.service.new(service).boot Utils.to_b(state)
  end

  private def get_status(prefix : String, all : Bool, &block : Service::OpenRC | Service::Systemd -> Nil)
    if all
      all_status &block
    else
      app_status prefix, &block
    end
  end

  def status(prefix : String, all : Bool, noboot : Bool, norun : Bool, services : Array(String)) : Nil
    print "RUN   " if !norun
    print "BOOT  " if !noboot
    puts "SERVICE\n"
    get_status(prefix, all) do |service|
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
      STDOUT.puts service.name
    end
  end

  def all_status
    ::System::Host.service.each do |app|
      yield ::System::Host.service.new app
    end
  end

  def app_status(prefix : String = PREFIX)
    Dir.each_child(Path.new(prefix).app) do |app|
      yield ::System::Host.service.new app
    end
  end
end
