require "spec"
require "file_utils"
require "../src/logger"

DPPM_CONFIG_FILE = File.expand_path __DIR__ + "/../config.con"
SAMPLES_DIR      = __DIR__ + "/samples"
# Comment to debug
Log.output = File.open File::DEVNULL, "w"
Log.error = File.open File::DEVNULL, "w"
TEST_APP_PACKAGE_NAME = "testapp"
TEST_LIB_PACKAGE_NAME = "libfake"
