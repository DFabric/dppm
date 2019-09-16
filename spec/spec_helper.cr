require "spec"
require "../src/logger"
require "../src/host"

{% if !flag?(:allow_root) %}
  if Process.root?
    abort <<-E
      Running specs as root is not recommended, unless in a test VM/container.
      They will interact with your system, with a risk to break it.
      Use the `-D allow_root` flag to allow specs to run as root.
    E
  end
{% end %}

DPPM_CONFIG_FILE = File.expand_path __DIR__ + "/../config.con"
SAMPLES_DIR      = __DIR__ + "/samples"
# Comment to debug
DPPM::Log.output = DPPM::Log.error = File.open File::NULL, "w"
TEST_APP_PACKAGE_NAME = "testapp"
TEST_LIB_PACKAGE_NAME = "libfake"

def spec_root_prefix : String
  File.tempname prefix: "temp-dppm-prefix", suffix: nil
end
