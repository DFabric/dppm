require "./prefix_helper"
require "../src/prefix"

describe DPPM::Prefix do
  it "downloads packages source with cli using config file mirror" do
    spec_with_prefix do |prefix|
      prefix.update
      children = Dir.new(prefix.path.to_s).children
      children.includes?("app").should be_true
      children.includes?("pkg").should be_true
      children.includes?("src").should be_true
      Dir[prefix.src.to_s + "/*/*"].should_not be_empty
    end
  end
end
