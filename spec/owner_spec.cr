require "./spec_helper"
require "../src/system/owner"

describe ::System::Owner do
  it "converts an user name to an uid" do
    ::System::Owner.to_uid("root").should eq 0
  end

  it "converts a group name to a gid" do
    ::System::Owner.to_gid("root").should eq 0
  end

  it "returns the passed uid as an Int from a String" do
    ::System::Owner.to_uid("0").should eq 0
  end

  it "converts an uid as to an user name" do
    ::System::Owner.to_user("0").should eq "root"
  end

  it "converts a group id as Int32 to its name" do
    ::System::Owner.to_group(0).should eq "root"
  end
end
