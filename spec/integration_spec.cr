require "./spec_helper"
require "./integration/*"

module IntegrationSpec
  extend self
end

describe IntegrationSpec do
  package = TEST_APP_PACKAGE_NAME
  prefix = IntegrationSpec.create_prefix File.tempname("_temp_dppm_prefix")

  begin
    IntegrationSpec.build_package prefix.path.to_s, package
    IntegrationSpec.add_application prefix_path: prefix.path.to_s, application: package, name: package

    IntegrationSpec.test_prefix_app prefix, package
    IntegrationSpec.upgrade_application prefix_path: prefix.path.to_s, application: package, version: "0.3.0"

    IntegrationSpec.delete_application prefix.path.to_s, package
    IntegrationSpec.clean_unused_packages prefix.path.to_s
  ensure
    prefix.delete
  end
end
