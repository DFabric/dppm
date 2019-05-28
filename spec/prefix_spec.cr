require "./spec_helper"
require "../src/prefix"

describe DPPM::Prefix do
  it "downloads packages source with cli using config file mirror" do
    prefix = DPPM::Prefix.new File.tempname(suffix: "_temp_dppm_prefix")
    prefix.create
    begin
      prefix.update
      children = Dir.new(prefix.path.to_s).children
      children.includes?("app").should be_true
      children.includes?("pkg").should be_true
      children.includes?("src").should be_true
      Dir[prefix.src.to_s + "/*/*"].should_not be_empty
    ensure
      FileUtils.rm_rf prefix.path.to_s
    end
  end
end
