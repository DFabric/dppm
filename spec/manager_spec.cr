require "./spec_helper"
require "../src/manager"

describe Manager do
  Dir.mkdir TEMP_DPPM_PREFIX
  custom_vars = ["name=" + TEST_APP_PACKAGE_NAME]

  it "builds an application" do
    build = Manager::Package::CLI.build(
      no_confirm: true,
      config: DPPM_CONFIG_FILE,
      mirror: nil,
      source: __DIR__ + "/samples",
      prefix: TEMP_DPPM_PREFIX,
      package: TEST_APP_PACKAGE_NAME,
      custom_vars: Array(String).new,
      version: nil).not_nil!
    build.pkg.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
    Dir.exists?(build.pkg.path).should be_true
  end

  it "adds an application" do
    add = Manager::Application::CLI.add(
      no_confirm: true,
      config: DPPM_CONFIG_FILE,
      mirror: nil,
      source: __DIR__ + "/samples",
      prefix: TEMP_DPPM_PREFIX,
      application: TEST_APP_PACKAGE_NAME,
      custom_vars: custom_vars,
      contained: false,
      noservice: true,
      socket: false,
      database: nil).not_nil!
    add.app.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
    Dir.exists?(add.app.path).should be_true
    add.app.each_lib &.includes?(TEST_LIB_PACKAGE_NAME).should be_true
  end

  it "deletes an application" do
    delete = Manager::Application::CLI.delete(
      no_confirm: true,
      config: DPPM_CONFIG_FILE,
      mirror: nil,
      source: __DIR__ + "/samples",
      prefix: TEMP_DPPM_PREFIX,
      application: TEST_APP_PACKAGE_NAME,
      custom_vars: custom_vars,
      keep_user_group: true,
      preserve_database: false).not_nil!
    delete.app.name.should eq TEST_APP_PACKAGE_NAME
    Dir.exists?(delete.app.path).should be_false
  end

  it "cleans the unused package" do
    clean = Manager::Package::CLI.clean(
      no_confirm: true,
      config: DPPM_CONFIG_FILE,
      mirror: nil,
      source: nil,
      prefix: TEMP_DPPM_PREFIX).not_nil!
    Dir.children(clean.prefix.pkg).should be_empty
  end

  FileUtils.rm_rf TEMP_DPPM_PREFIX
end
