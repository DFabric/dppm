require "./cmd"
require "./httpget"
require "./manager/*"
require "./path"
require "./service"
require "./system"

module Manager
  extend self
  CONFIG_FILE = "./config.ini"
  PREFIX      = ::System::Owner.root? ? "/srv/dppm" : ENV["HOME"] + "/.dppm"

  def pkg_exists?(dir)
    raise "doesn't exist: #{dir}/pkg.yml" if !File.exists? dir + "/pkg.yml"
  end

  def cli_confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end
end
