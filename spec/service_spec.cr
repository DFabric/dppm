require "./spec_helper"
require "../src/service"
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

def assert_service(service)
  Service.init = service

  user = group = TEST_APP_PACKAGE_NAME
  test_prefix = Prefix.new(__DIR__ + "/service_test", create: true)
  test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
  FileUtils.cp_r SAMPLES_DIR + '/' + TEST_APP_PACKAGE_NAME, test_app.path

  service_config = test_app.service.config.class.new
  test_app.service.file = test_app.service_file

  it "creates a service" do
    test_app.service_create user, group
  end

  it "parses the service" do
    test_app.service.config
  end

  it "gets user value" do
    test_app.service.config.user.should eq user
  end

  it "checks service file building" do
    File.read(test_app.service_file).should eq test_app.service.config_build
  end

  it "verifies PATH environment variable" do
    test_app.service.config.env_vars["PATH"].should eq test_app.path_env_var
  end

  FileUtils.rm_r test_prefix.path
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
