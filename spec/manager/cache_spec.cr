require "../spec_helper"
require "../../src/manager"

describe Manager::Source::Cache do
  it "downloads with cli using config file mirror" do
    Dir.mkdir TEMP_DPPM_PREFIX
    begin
      Manager::Source::Cache.cli DPPM_CONFIG_FILE, nil, nil, TEMP_DPPM_PREFIX, true
      children = Dir.new(TEMP_DPPM_PREFIX).children
      children.includes?("app").should be_true
      children.includes?("pkg").should be_true
      children.includes?("src").should be_true

      Dir[Prefix.new(TEMP_DPPM_PREFIX).src + "/*/*"].should_not be_empty
    ensure
      FileUtils.rm_r TEMP_DPPM_PREFIX
    end
  end
end
