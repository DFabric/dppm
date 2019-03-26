require "con"

module DPPM
  extend self

  def build_date : String
    {{ `date --utc -Iminutes`.stringify.chomp }}
  end

  def build_commit : String
    {{ `git rev-parse --short HEAD`.stringify.chomp }}
  end

  def version : String
    {{ `date --utc +"%Y.%m.%d"`.stringify.chomp }}
  end
end

require "./cli"

# TODO: integrate the DPPM API repository
def server(**args)
  Log.output.puts "available soon! (press CTRL+C)"
  sleep
end

# TODO: change to `dppm api`
CLI.run(
  server: {
    info:   "Start the dppm API server",
    action: "server",
  }
)
