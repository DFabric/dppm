require "spec"
require "../src/logger"
require "../src/host"
require "file_utils"

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
TEST_APP_PACKAGE_NAME = "testapp"
TEST_LIB_PACKAGE_NAME = "libfake"

def spec_temp_prefix : String
  File.tempname prefix: "temp-dppm-prefix", suffix: nil
end

def spec_with_tempdir(directory : String = spec_temp_prefix, &block)
  Dir.mkdir directory
  begin
    yield directory
  ensure
    FileUtils.rm_rf directory
  end
end

DPPM::Logger.output = DPPM::Logger.error = File.open File::NULL, "w"
