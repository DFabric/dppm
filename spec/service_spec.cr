require "./spec_helper"
require "../src/service"
require "../src/prefix"
require "file_utils"

module Service
  def self.init=(@@init)
    @@supported = true
  end

  module InitSystem
    def file=(@file)
    end
  end

  struct Systemd
    def self.version=(@@version)
    end
  end
end

def assert_service(service, file = __FILE__, line = __LINE__)
  Service.init = service

  user = group = TEST_APP_PACKAGE_NAME
  test_prefix = Prefix.new File.tempname("_dppm_service_test")
  test_prefix.create
  test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
  FileUtils.cp_r SAMPLES_DIR + '/' + TEST_APP_PACKAGE_NAME, test_app.path.to_s

  service_config = test_app.service.config.class.new
  test_app.service.file = test_app.service_file.to_s

  it "creates a service", file, line do
    test_app.service_create
  end

  it "parses the service", file, line do
    test_app.service.config
  end

  it "gets user value", file, line do
    test_app.service.config.user.should eq test_app.owner.user.name
  end

  it "checks service file building", file, line do
    File.read(test_app.service_file).should eq test_app.service.config_build
  end

  it "verifies PATH environment variable", file, line do
    test_app.service.config.env_vars["PATH"].should eq test_app.path_env_var
  end

  FileUtils.rm_r test_prefix.path.to_s
  Service.init = nil
end

describe Service do
  describe Service::OpenRC do
    assert_service Service::OpenRC
  end

  describe Service::Systemd do
    describe "version < 236 with file logging workaround" do
      Service::Systemd.version = 230
      assert_service Service::Systemd
    end

    describe "recent version supporting file logging" do
      Service::Systemd.version = 240
      assert_service Service::Systemd
    end
  end
end
