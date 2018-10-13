require "spec"
require "../src/logger"
Log.output = File.open "/dev/null", "a"
Log.error = File.open "/dev/null", "a"
