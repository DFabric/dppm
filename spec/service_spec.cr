require "./spec_helper"
require "../src/service"
require "file_utils"

module Service
  def self.init=(@@init)
    @@supported = true
  end

  struct Systemd
    def self.version=(@@version)
    end
  end
end

def test_service
  user = group = TEST_APP_PACKAGE_NAME
  test_prefix = Prefix.new(__DIR__ + "/service_test", create: true)
  test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
  FileUtils.cp_r __DIR__ + "/samples/" + TEST_APP_PACKAGE_NAME, test_app.path

  service_config = test_app.service.config.class.new

  it "creates a service" do
    test_app.service_create user, group
  end

  it "parses the service" do
    service_config = test_app.service.config.class.read test_app.service_file
  end

  it "gets user value" do
    service_config.user.should eq user
  end

  it "checks service file building" do
    File.read(test_app.service_file).should eq service_config.build
  end

  it "verifies PATH environment variable" do
    service_config.env_vars["PATH"].should eq test_app.path_env_var
  end

  FileUtils.rm_r test_prefix.path
end

describe Service do
  describe Service::OpenRC do
    Service.init = Service::OpenRC
    test_service
    Service.init = nil
  end

  describe Service::Systemd do
    describe "version < 236 with file logging workaround" do
      Service.init = Service::Systemd
      Service::Systemd.version = 230
      test_service
      Service.init = nil
    end

    describe "recent version supporting file logging" do
      Service.init = Service::Systemd
      Service::Systemd.version = 240
      test_service
      Service.init = nil
    end
  end
end
