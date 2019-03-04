require "./spec_helper"
require "../src/prefix"

describe Prefix do
  it "downloads packages source with cli using config file mirror" do
    prefix = Prefix.new File.tempname(suffix: "_temp_dppm_prefix")
    prefix.create
    begin
      prefix.update
      children = Dir.new(prefix.path).children
      children.includes?("app").should be_true
      children.includes?("pkg").should be_true
      children.includes?("src").should be_true
      Dir[prefix.src + "/*/*"].should_not be_empty
    ensure
      FileUtils.rm_rf prefix.path
    end
  end
end
