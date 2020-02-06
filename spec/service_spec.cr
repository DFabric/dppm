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

    # systemctl may not exist
    private def daemon_reload
    end
  end
end

struct DPPM::Prefix::App
  def service=(@service)
  end
end

def spec_with_service_app(service, &block)
  spec_with_tempdir do |path|
    test_prefix = DPPM::Prefix.new path, source_path: SAMPLES_DIR
    test_prefix.create
    test_prefix.update
    test_pkg = test_prefix.new_pkg TEST_APP_PACKAGE_NAME
    test_app = test_pkg.new_app.add { }
    test_app.service = service.new test_app.name
    test_app.service.file = test_app.service_path / "test_service"
    test_app.service_create

    yield test_app
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
        app.service.config.build str
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
