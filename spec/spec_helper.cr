require "spec"
require "../src/logger"

TEMP_DPPM_PREFIX = __DIR__ + "/temp_dppm_prefix"
Log.output = File.open "/dev/null", "a"
Log.error = File.open "/dev/null", "a"
