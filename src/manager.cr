require "./config"
require "./httpget"
require "./manager/*"
require "./path"
require "./service"
require "./system"

module Manager
  extend self
  PREFIX = ::System::Owner.root? ? "/srv/dppm" : ENV["HOME"] + "/.dppm"

  def cli_confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end
end
