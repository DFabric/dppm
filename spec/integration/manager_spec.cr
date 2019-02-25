require "../../src/manager"

module IntegrationSpec
  def build_package(package : String)
    it "builds an application" do
      build = Manager::Package::CLI.build(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        mirror: nil,
        source: SAMPLES_DIR,
        prefix: TEMP_DPPM_PREFIX,
        package: package,
        custom_vars: Array(String).new,
        version: nil).not_nil!
      build.pkg.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
      Dir.exists?(build.pkg.path).should be_true
    end
  end

  def add_application(application : String, name : String)
    it "adds an application" do
      add = Manager::Application::CLI.add(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        mirror: nil,
        source: SAMPLES_DIR,
        prefix: TEMP_DPPM_PREFIX,
        application: application,
        custom_vars: ["name=" + name],
        contained: false,
        noservice: true,
        socket: false).not_nil!
      add.app.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
    end
  end

  def delete_application(application : String)
    it "deletes an application" do
      delete = Manager::Application::CLI.delete(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        mirror: nil,
        source: SAMPLES_DIR,
        prefix: TEMP_DPPM_PREFIX,
        application: application,
        custom_vars: nil,
        keep_user_group: false,
        preserve_database: false).not_nil!
      delete.app.name.should eq TEST_APP_PACKAGE_NAME
      Dir.exists?(delete.app.path).should be_false
    end
  end
end
