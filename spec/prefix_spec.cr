require "./spec_helper"
require "../src/prefix"

describe Prefix do
  it "downloads with cli using config file mirror" do
    MainConfig.file = DPPM_CONFIG_FILE
    prefix = Prefix.new TEMP_DPPM_PREFIX, true
    prefix.update
    children = Dir.new(TEMP_DPPM_PREFIX).children
    children.includes?("app").should be_true
    children.includes?("pkg").should be_true
    children.includes?("src").should be_true

    Dir[prefix.src + "/*/*"].should_not be_empty
  end
ensure
  FileUtils.rm_rf TEMP_DPPM_PREFIX
end
