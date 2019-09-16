require "./spec_helper"
require "../src/service"
require "../src/prefix"
require "file_utils"

module Service
  def self.init=(@@init)
    @@initialized = true
  end

  module InitSystem
    def file=(@file)
    end
  end

  class Systemd
    def self.version=(@@version)
    end
  end
end

def assert_service(service, file = __FILE__, line = __LINE__)
  Service.init = service

  test_prefix = DPPM::Prefix.new File.tempname("_dppm_service_test")
  test_prefix.create
  test_prefix.ensure_app_dir
  test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
  FileUtils.cp_r Path[SAMPLES_DIR, TEST_APP_PACKAGE_NAME].to_s, test_app.path.to_s

  test_app.service.file = test_app.service_file

  it "creates a service", file, line do
    config = test_app.service_create.config
    config.user.should be_a String
    config.group.should be_a String
    config.directory.should be_a String
    config.command.should be_a String
    config.reload_signal.should be_a String
    config.description.should be_a String
    config.log_output.should be_a String
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

  test_prefix.delete
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
