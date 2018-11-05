require "./spec_helper"
require "../src/manager"

describe Manager do
  Dir.mkdir TEMP_DPPM_PREFIX
  package = "test"
  app_name = ""
  version = ""

  it "builds an application" do
    add = Manager::Package::CLI.build(
      no_confirm: true,
      config: "#{__DIR__}/../config.ini",
      mirror: nil,
      source: "#{__DIR__}/samples",
      prefix: TEMP_DPPM_PREFIX,
      package: package,
      custom_vars: Array(String).new).not_nil!
    version = add.version
    (app_name = add.name).starts_with?(package).should be_true
  end

  it "cleans the unused package" do
    set = Set(String).new
    set << package + '_' + version
    Manager::Package::CLI.clean(
      no_confirm: true,
      config: "#{__DIR__}/../config.ini",
      mirror: nil,
      source: nil,
      prefix: TEMP_DPPM_PREFIX).not_nil!.packages.should eq set
  end

  it "adds an application" do
    add = Manager::Application::CLI.add(
      no_confirm: true,
      config: "#{__DIR__}/../config.ini",
      mirror: nil,
      source: "#{__DIR__}/samples",
      prefix: TEMP_DPPM_PREFIX,
      application: package,
      custom_vars: Array(String).new,
      contained: false,
      noservice: true,
      socket: false).not_nil!
    version = add.version
    (app_name = add.name).starts_with?(package).should be_true
  end

  it "deletes an application" do
    delete = Manager::Application::CLI.delete(
      no_confirm: true,
      config: "#{__DIR__}/../config.ini",
      mirror: nil,
      source: "#{__DIR__}/samples",
      prefix: TEMP_DPPM_PREFIX,
      application: app_name,
      custom_vars: Array(String).new,
      keep_user_group: true).not_nil!
    delete.name.should eq app_name
  end

  FileUtils.rm_rf TEMP_DPPM_PREFIX
end
