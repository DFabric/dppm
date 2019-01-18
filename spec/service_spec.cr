require "./spec_helper"
require "../src/service"
require "file_utils"

module Service
  def self.init=(@@init)
    @@supported = true
  end
end

describe Service do
  if !File.exists? "/bin/systemctl"
    File.write "/bin/systemctl", "#!/bin/sh\necho systemd 240"
    File.chmod "/bin/systemctl", 0o755
  end

  user = group = TEST_APP_PACKAGE_NAME

  {% for sysinit in %w(OpenRC Systemd) %}
    describe {{sysinit}} do
      Service.init = Service::{{sysinit.id}}
      test_prefix = Prefix.new(__DIR__ + "/service_test", create: true)
      test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
      FileUtils.cp_r __DIR__ + "/samples/" + TEST_APP_PACKAGE_NAME, test_app.path


      service_config = Service::{{sysinit.id}}::Config.new

      it "creates a service" do
        test_app.service_create user, group
      end

      it "parses the service" do
        service_config = Service::{{sysinit.id}}::Config.new test_app.service_file
      end

      it "checks values of sections" do
        user.should eq service_config.get("user")
        group.should eq service_config.get("group")
      end

      it "verifies the builded service" do
        File.read(test_app.service_file).should eq service_config.build
      end

      it "adds environment variables" do
        service_config.env_set "TEST", "some_test"
        service_config.env_get("TEST").should eq "some_test"
        service_config.env_set "ENV", "production"
        service_config.env_get("ENV").should eq "production"
      end

      FileUtils.rm_r test_prefix.path
    end
  {% end %}
end
