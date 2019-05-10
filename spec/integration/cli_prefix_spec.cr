require "../../src/cli"

module IntegrationSpec
  def build_package(prefix_path : String, package : String)
    it "builds an application" do
      pkg = DPPM::CLI::Pkg.build(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        source_name: Prefix.default_source_name,
        source_path: SAMPLES_DIR,
        prefix: prefix_path,
        package: package,
        custom_vars: Array(String).new)
      pkg.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
      pkg.exists?.should eq pkg
    end
  end

  def add_application(prefix_path : String, application : String, name : String)
    it "adds an application" do
      app = DPPM::CLI::App.add(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        group: Prefix.default_group,
        source_name: Prefix.default_source_name,
        source_path: SAMPLES_DIR,
        prefix: prefix_path,
        application: application,
        name: name,
        contained: false,
        noservice: true,
        socket: false)
      app.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
    end
  end

  def upgrade_application(prefix_path : String, application : String, version : String)
    it "upgrades an application" do
      app = DPPM::CLI::App.upgrade(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        group: Prefix.default_group,
        source_name: Prefix.default_source_name,
        source_path: SAMPLES_DIR,
        prefix: prefix_path,
        application: application,
        contained: false,
        version: version,
      )
      app.pkg.version.should eq version
    end
  end

  def delete_application(prefix_path : String, application : String)
    it "deletes an application" do
      app = DPPM::CLI::App.delete(
        no_confirm: true,
        prefix: prefix_path,
        group: Prefix.default_group,
        application: application,
        keep_user_group: false,
        preserve_database: false).not_nil!
      app.name.should eq TEST_APP_PACKAGE_NAME
      app.exists?.should be_nil
    end
  end
end
