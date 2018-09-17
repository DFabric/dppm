require "spec"
require "../src/logger"
Log.destination = File.open "/dev/null", "a"
