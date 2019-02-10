require "./spec_helper"
require "./integration/*"

module IntegrationSpec
  extend self
end

describe IntegrationSpec do
  package = TEST_APP_PACKAGE_NAME
  prefix = IntegrationSpec.create_prefix TEMP_DPPM_PREFIX

  IntegrationSpec.build_package package
  IntegrationSpec.add_application application: package, name: package

  IntegrationSpec.test_prefix_app prefix, package

  IntegrationSpec.delete_application package
  IntegrationSpec.clean_package
ensure
  FileUtils.rm_rf TEMP_DPPM_PREFIX
end
