require "./openrc"
require "./systemd"

module Service::CLI
  extend self

  def boot(prefix : String, service : String, state : String) : Bool
    Service.init.new(service).boot Utils.to_b(state)
  end

  private def get_status(prefix : String, all : Bool, &block : Service::OpenRC | Service::Systemd -> Nil)
    if all
      all_status &block
    else
      app_status(prefix, &block)
    end
  end

  def status(prefix : String, all : Bool, noboot : Bool, norun : Bool, services : Array(String)) : Nil
    print "RUN   " if !norun
    print "BOOT  " if !noboot
    puts "SERVICE\n"
    if services.empty?
      get_status(prefix, all) do |service|
        print_run_state(service) if !norun
        print_boot_state(service) if !noboot
        puts service.name
      end
    else
      root_prefix = Prefix.new prefix
      services.each do |service_name|
        service = root_prefix.new_app(service_name).service
        print_run_state(service) if !norun
        print_boot_state(service) if !noboot
        puts service.name
      end
    end
  end

  private def print_run_state(service : Service::OpenRC | Service::Systemd)
    if run = service.run?
      STDOUT << run.colorize.green << "  "
    else
      STDOUT << run.colorize.red << ' '
    end
  end

  private def print_boot_state(service : Service::OpenRC | Service::Systemd)
    if boot = service.boot?
      STDOUT << boot.colorize.green << "  "
    else
      STDOUT << boot.colorize.red << ' '
    end
  end

  def all_status
    Service.init.each do |service_name|
      yield Service.init.new service_name
    end
  end

  def app_status(prefix : String = PREFIX, &block)
    Prefix.new(prefix).each_app do |app|
      yield app.service
    end
  end
end
