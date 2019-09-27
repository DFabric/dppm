require "../src/cli"
require "./prefix_helper"
require "file_utils"

def install_dppm(prefix : String)
  DPPM::CLI.install_dppm(
    no_confirm: true,
    config: DPPM_CONFIG_FILE,
    prefix: prefix,
    group: DPPM::Prefix.default_group,
    source_name: DPPM::Prefix.default_source_name,
    source_path: nil
  )
end

def build_package(prefix_path : String, package : String = TEST_APP_PACKAGE_NAME)
  pkg = DPPM::CLI::Pkg.build(
    no_confirm: true,
    config: DPPM_CONFIG_FILE,
    source_name: DPPM::Prefix.default_source_name,
    source_path: SAMPLES_DIR,
    prefix: prefix_path,
    package: package,
    custom_vars: Array(String).new)
  pkg.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
  pkg.exists?.should eq pkg
end

def add_application(prefix_path : String, application : String = TEST_APP_PACKAGE_NAME, name : String = TEST_APP_PACKAGE_NAME, version : String? = nil)
  app = DPPM::CLI::App.add(
    no_confirm: true,
    config: DPPM_CONFIG_FILE,
    group: DPPM::Prefix.default_group,
    source_name: DPPM::Prefix.default_source_name,
    source_path: SAMPLES_DIR,
    prefix: prefix_path,
    application: application,
    name: name,
    version: version,
    contained: false,
    noservice: true,
    socket: false)
  app.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
  app.exists?.should eq app
end

def upgrade_application(prefix_path : String, version : String, application : String = TEST_APP_PACKAGE_NAME)
  app = DPPM::CLI::App.upgrade(
    no_confirm: true,
    config: DPPM_CONFIG_FILE,
    group: DPPM::Prefix.default_group,
    source_name: DPPM::Prefix.default_source_name,
    source_path: SAMPLES_DIR,
    prefix: prefix_path,
    application: application,
    contained: false,
    version: version,
  )
  app.pkg.version.should eq version
end

def delete_application(prefix_path : String, application : String = TEST_APP_PACKAGE_NAME)
  app = DPPM::CLI::App.delete(
    no_confirm: true,
    prefix: prefix_path,
    group: DPPM::Prefix.default_group,
    application: application,
    keep_user_group: false,
    preserve_database: false).not_nil!
  app.name.should eq application
  app.exists?.should be_nil
end

describe DPPM::CLI do
  it "installs DPPM" do
    spec_with_tempdir do |prefix|
      install_dppm prefix
    end
  end

  it "uninstalls DPPM" do
    spec_with_tempdir do |prefix|
      install_dppm prefix

      DPPM::CLI.uninstall_dppm(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        prefix: prefix,
        group: DPPM::Prefix.default_group,
        source_name: DPPM::Prefix.default_source_name,
        source_path: nil
      )
    end
  end

  describe DPPM::CLI::Pkg do
    it "cleans unused packages" do
      spec_with_prefix do |prefix|
        build_package prefix.path.to_s
        Dir.rmdir (prefix.app / "dppm").to_s
        packages = prefix.clean_unused_packages(false) { }
        packages.not_nil!.should eq Set{"libfake_0.0.1", "testapp_0.2.0"}
        Dir.children(prefix.pkg.to_s).should be_empty
      end
    end

    it "builds a packages" do
      spec_with_prefix do |prefix|
        build_package prefix.path.to_s
      end
    end
  end

  describe DPPM::CLI::App do
    it "adds an application with a version and no package built" do
      spec_with_prefix do |prefix|
        add_application prefix_path: prefix.path.to_s, version: "0.3.0"
        delete_application prefix.path.to_s
      end
    end

    it "adds an application" do
      spec_with_prefix do |prefix|
        add_application prefix_path: prefix.path.to_s
        delete_application prefix.path.to_s
      end
    end

    it "upgrades an application" do
      spec_with_prefix do |prefix|
        add_application prefix_path: prefix.path.to_s
        upgrade_application prefix_path: prefix.path.to_s, version: "0.3.0"
        delete_application prefix.path.to_s
      end
    end

    it "deletes an application" do
      spec_with_prefix do |prefix|
        add_application prefix_path: prefix.path.to_s
        delete_application prefix.path.to_s
      end
    end
  end
end
