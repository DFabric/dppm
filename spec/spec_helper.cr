require "spec"
require "file_utils"
require "../src/logger"

DPPM_CONFIG_FILE = File.expand_path __DIR__ + "/../config.con"
TEMP_DPPM_PREFIX = __DIR__ + "/temp_dppm_prefix"
SAMPLES_DIR      = __DIR__ + "/samples"
# Comment to debug
Log.output = File.open "/dev/null", "a"
Log.error = File.open "/dev/null", "a"
TEST_APP_PACKAGE_NAME = "testapp"
TEST_LIB_PACKAGE_NAME = "libfake"
