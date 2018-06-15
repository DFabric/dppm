require "./spec_helper"

describe Utils do
  it "changes the permissions of the directory recursively" do
    path = __DIR__ + "/chmod_r_test"
    begin
      Dir.mkdir path
      Dir.mkdir File.join(path, "a")
      File.write File.join(path, "a/b"), ""

      permission = File::Permissions.new 0o754
      Utils.chmod_r path, permission.value
      File.info(File.join path, "a").permissions.should eq permission
      File.info(File.join path, "a/b").permissions.should eq permission
    ensure
      FileUtils.rm_r(path)
    end
  end

  it "changes the owner of the directory recursively" do
    # changing owners requires special privileges, so we test that method calls do compile
    typeof(Utils.chown_r "/tmp/test")
    typeof(Utils.chown_r("/tmp/test", uid: 1001, gid: 100, follow_symlinks: true))
  end

  it "converts to an array" do
    Utils.to_array("a.b.c").should eq ["a", "b", "c"]
  end

  describe "String to_type" do
    it "converts a quoted string to an unquoted one" do
      Utils.to_type("\"string\"", true).should eq "string"
    end
    it "returns the passed string" do
      Utils.to_type("string", false).should eq "string"
    end
    it "converts to a `true` bool" do
      Utils.to_type("true").should eq true
    end
    it "converts to a `false` bool" do
      Utils.to_type("false").should eq false
    end
    it "converts to an empty hash" do
      Utils.to_type("{}").should eq Hash(String, String).new
    end
    it "converts to an empty array" do
      Utils.to_type("[]").should eq Array(String).new
    end
    it "converts to an Int64" do
      Utils.to_type("72").should eq 72
    end
    it "converts to a Float64" do
      Utils.to_type("1.3").should eq 1.3
    end
  end

  it "converts to boolean" do
    Utils.to_b("true").should eq true
    Utils.to_b("false").should eq false
  end

  it "checks if a string is a http url" do
    Utils.is_http?("http://example.com").should eq true
    Utils.is_http?("https://example.com").should eq true
    Utils.is_http?("ftp://example.com").should eq false
  end
end
