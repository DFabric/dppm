require "./spec_helper"

describe Owner do
  it "converts an user name to its id" do
    Owner.to_id("root", "uid").should eq(0)
  end

  it "converts a group name to its id" do
    Owner.to_id("root", "gid").should eq(0)
  end

  it "returns the passed uid as an Int from a String" do
    Owner.to_id("0", "uid").should eq(0)
  end

  it "returns the passed gid as an Int from an Int" do
    Owner.to_id(0, "gid").should eq(0)
  end

  it "converts an user id as String to its name" do
    Owner.from_id("0", "uid").should eq("root")
  end

  it "converts a group id as Int32 to its name" do
    Owner.from_id(0, "gid").should eq("root")
  end

  it "shouldn't be a generated id" do
    Owner.generated?("abcd", "abcd").should eq false
  end

  it "should be a generated id" do
    Owner.generated?("abcd_1a2b3", "abcd").should eq true
  end
end
