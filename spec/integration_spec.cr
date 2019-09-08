require "./spec_helper"
require "./integration/*"

module IntegrationSpec
  extend self
end

describe IntegrationSpec do
  package = TEST_APP_PACKAGE_NAME
  prefix = IntegrationSpec.create_prefix spec_root_prefix

  begin
    it "adds an application with a version and no package built" do
      IntegrationSpec.add_application prefix_path: prefix.path.to_s, application: package, name: package, version: "0.3.0"
      IntegrationSpec.delete_application prefix.path.to_s, package
    end

    it "builds an application" do
      IntegrationSpec.build_package prefix.path.to_s, package
    end

    it "adds an application" do
      IntegrationSpec.add_application prefix_path: prefix.path.to_s, application: package, name: package
    end

    IntegrationSpec.test_prefix_app prefix, package

    it "upgrades an application" do
      IntegrationSpec.upgrade_application prefix_path: prefix.path.to_s, application: package, version: "0.3.0"
    end

    it "deletes an application" do
      IntegrationSpec.delete_application prefix.path.to_s, package
    end

    IntegrationSpec.clean_unused_packages prefix.path.to_s
  ensure
    prefix.delete
  end
end
