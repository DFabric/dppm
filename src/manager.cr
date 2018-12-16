require "./config"
require "./host"
require "./httpget"
require "./manager/*"
require "./path"
require "./service"

module Manager
  extend self
  PREFIX = Process.root? ? "/srv/dppm" : ENV["HOME"] + "/.dppm"

  def cli_confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end
end
