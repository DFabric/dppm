require "../../src/manager"

module IntegrationSpec
  def build_package(package : String)
    it "builds an application" do
      pkg = Manager::Package::CLI.build(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        mirror: nil,
        source: SAMPLES_DIR,
        prefix: TEMP_DPPM_PREFIX,
        package: package,
        custom_vars: Array(String).new,
        version: nil)
      pkg.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
      Dir.exists?(pkg.path).should be_true
    end
  end

  def add_application(application : String, name : String)
    it "adds an application" do
      app = Manager::Application::CLI.add(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        mirror: nil,
        source: SAMPLES_DIR,
        prefix: TEMP_DPPM_PREFIX,
        application: application,
        custom_vars: ["name=" + name],
        contained: false,
        noservice: true,
        socket: false)
      app.name.starts_with?(TEST_APP_PACKAGE_NAME).should be_true
    end
  end

  def delete_application(application : String)
    it "deletes an application" do
      delete = Manager::Application::CLI.delete(
        no_confirm: true,
        prefix: TEMP_DPPM_PREFIX,
        application: application,
        keep_user_group: false,
        preserve_database: false).not_nil!
      delete.name.should eq TEST_APP_PACKAGE_NAME
      Dir.exists?(delete.path).should be_false
    end
  end
end
