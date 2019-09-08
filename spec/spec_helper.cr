require "spec"
require "../src/logger"

DPPM_CONFIG_FILE = File.expand_path __DIR__ + "/../config.con"
SAMPLES_DIR      = __DIR__ + "/samples"
# Comment to debug
DPPM::Log.output = DPPM::Log.error = File.open File::NULL, "w"
TEST_APP_PACKAGE_NAME = "testapp"
TEST_LIB_PACKAGE_NAME = "libfake"

def spec_root_prefix : String
  File.tempname prefix: "temp-dppm-prefix", suffix: nil
end
