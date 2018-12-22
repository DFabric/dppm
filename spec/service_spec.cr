require "./spec_helper"
require "../src/service"
require "file_utils"

describe Service do
  test_prefix = Prefix.new(__DIR__ + "/service_test", create: true)
  test_app = test_prefix.new_app(TEST_APP_PACKAGE_NAME)
  FileUtils.cp_r __DIR__ + "/samples/" + TEST_APP_PACKAGE_NAME, test_app.path

  user = group = TEST_APP_PACKAGE_NAME

  {% for sysinit in %w(OpenRC Systemd) %}
    describe {{sysinit}} do
      service = Service::{{sysinit.id}}::Config.new

      it "creates a service" do
        Service::{{sysinit.id}}.new(TEST_APP_PACKAGE_NAME).create(test_app, user, group)
      end

      it "parses the service" do
        service = Service::{{sysinit.id}}::Config.parse(test_app.path + Service::ROOT_PATH + {{sysinit.downcase}})
      end

      it "checks values of sections" do
        user.should eq service.get("user")
        group.should eq service.get("group")
      end

      it "verifies the builded service" do
        File.read(test_app.path + Service::ROOT_PATH + {{sysinit.downcase}}).should eq service.build
      end

      it "adds environment variables" do
        service.env_set "TEST", "some_test"
        service.env_set "ENV", "production"
      end

      it "checks value of environment variables" do
        service.env_get("TEST").should eq "some_test"
        service.env_get("ENV").should eq "production"
      end
    end
  {% end %}

  FileUtils.rm_r test_prefix.path
end
