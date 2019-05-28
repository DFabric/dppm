require "./spec_helper"
require "../src/utils"

describe DPPM::Utils do
  it "changes the permissions of the directory recursively" do
    path = __DIR__ + "/chmod_r_test"
    begin
      Dir.mkdir path
      Dir.mkdir File.join(path, "a")
      File.write File.join(path, "a/b"), ""

      permission = File::Permissions.new 0o754
      DPPM::Utils.chmod_r path, permission.value
      File.info(File.join path, "a").permissions.should eq permission
      File.info(File.join path, "a/b").permissions.should eq permission
    ensure
      FileUtils.rm_r(path)
    end
  end

  it "changes the owner of the directory recursively" do
    # changing owners requires special privileges, so we test that method calls do compile
    typeof(DPPM::Utils.chown_r "/tmp/test")
    typeof(DPPM::Utils.chown_r("/tmp/test", uid: 1001, gid: 100, follow_symlinks: true))
  end

  it "converts to boolean" do
    DPPM::Utils.to_b("true").should eq true
    DPPM::Utils.to_b("false").should eq false
  end
end
