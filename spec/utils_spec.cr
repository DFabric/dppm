require "./spec_helper"

describe Utils do
  describe "chmod_r" do
    it "changes the permissions of the directory recursively" do
      path = Dir.current + '/' + "chmod_r_test"
      begin
        Dir.mkdir(path)
        Dir.mkdir(File.join(path, "a"))
        File.write(File.join(path, "a/b"), "")

        Utils.chmod_r(path, 0o775)
        File.stat(File.join(path, "a")).perm.should eq(0o775)
        File.stat(File.join(path, "a/b")).perm.should eq(0o775)
      ensure
        FileUtils.rm_r(path)
      end
    end
  end

  describe "chown_r" do
    it "change the owner of the directory recursively" do
      # changing owners requires special privileges, so we test that method calls do compile
      typeof(Utils.chown_r("/tmp/test"))
      typeof(Utils.chown_r("/tmp/test", uid: 1001, gid: 100, follow_symlinks: true))
    end
  end
end
