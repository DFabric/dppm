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

def spec_with_service_app(service, &block)
  Service.init = service

  spec_with_tempdir do |path|
    test_prefix = DPPM::Prefix.new path
    test_prefix.create
    test_prefix.ensure_app_dir
    test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
    FileUtils.cp_r Path[SAMPLES_DIR, TEST_APP_PACKAGE_NAME].to_s, test_app.path.to_s

    test_app.service.file = test_app.service_file
    test_app.service_create.config

    begin
      yield test_app
    ensure
      Service.init = nil
    end
  end
end

def assert_service(service, file = __FILE__, line = __LINE__)
  spec_with_service_app service do |app|
    it "creates a service config", file, line do
      config = app.service.config
      config.user.should be_a String
      config.group.should be_a String
      config.directory.should be_a String
      config.command.should be_a String
      config.reload_signal.should be_a String
      config.description.should be_a String
      config.log_output.should be_a String
    end

    it "parses the service", file, line do
      app.service.config
    end

    it "gets user value", file, line do
      app.service.config.user.should eq app.owner.user.name
    end

    it "verifies PATH environment variable", file, line do
      app.service.config.env_vars["PATH"].should eq app.path_env_var
    end
  end

  it "creates a service file building", file, line do
    spec_with_service_app service do |app|
      service_config = String.build do |str|
        app.service.config_build str
      end
      File.read(app.service_file).should eq service_config
    end
  end
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
