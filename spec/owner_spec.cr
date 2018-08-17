require "./spec_helper"

describe Owner do
  it "converts an user name to an uid" do
    Owner.to_uid("root").should eq 0
  end

  it "converts a group name to a gid" do
    Owner.to_gid("root").should eq 0
  end

  it "returns the passed uid as an Int from a String" do
    Owner.to_uid("0").should eq 0
  end

  it "converts an uid as to an user name" do
    Owner.to_user("0").should eq "root"
  end

  it "converts a group id as Int32 to its name" do
    Owner.to_group(0).should eq "root"
  end

  it "shouldn't be a generated id" do
    Owner.generated?("abcd", "abcd").should eq false
  end

  it "should be a generated id" do
    Owner.generated?("abcd_1a2b3", "abcd").should eq true
  end
end
