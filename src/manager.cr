require "exec"
require "./config"
require "./database"
require "./host"
require "./http_helper"
require "./logger"
require "./main_config"
require "./prefix"
require "./service"
require "./manager/*"

module Manager
  extend self
  PREFIX = begin
    if Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end

  def cli_confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end

  def exec(command : String, args : Array(String) | Tuple) : String
    Exec.new command, args, output: Log.output, error: Log.error do |process|
      raise "execution returned an error: #{command} #{args.join ' '}" if !process.wait.success?
    end
    "success"
  end
end
