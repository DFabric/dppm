require "./spec_helper"

describe Cmd::Run do
  path = Dir.current + "/cmd_test"
  temppath = path + "/command"
  Dir.mkdir path
  Dir.cd path
  File.write "test_file", "data"
  cmd = Cmd::Run.new(Array(String).new, {"pkgdir" => path})

  describe "command" do
    it "current" do
      cmd.command("current").should eq path
    end

    it "ls" do
      cmd.command("ls").should eq ".\n..\ntest_file"
    end

    describe "file_exists?" do
      it "file" { cmd.command("file_exists? test_file").should be_true }
      it "directory" { cmd.command("file_exists? " + path).should be_true }
      it "false" { cmd.command("file? " + path).should be_false }
    end

    describe "file? true" do
      it "file" { cmd.command("file? test_file").should be_true }
      it "directory" { cmd.command("file? " + path).should be_false }
    end

    describe "dir_exists?" do
      it "file" { cmd.command("dir_exists? test_file").should be_false }
      it "directory" { cmd.command("dir_exists? " + path).should be_true }
    end

    it "cd" do
      Dir.cd path do
        Dir.mkdir temppath
        cmd.command("cd " + File.basename temppath)
        Dir.current.should eq temppath
        Dir.rmdir temppath
      end
    end

    it "cp" do
      cmd.command("cp test_file other")
      File.read("other").should eq "data"
    end

    it "mv" do
      cmd.command("mv test_file moved_file")
      File.read("moved_file").should eq "data"
    end

    it "rm" do
      File.write "test_rm", ""
      cmd.command("rm test_rm")
      File.exists?("test_rm").should be_false
    end

    it "rm_r" do
      Dir.mkdir temppath
      cmd.command("rm_r " + temppath)
      Dir.exists?(temppath).should be_false
    end

    it "mkdir" do
      cmd.command("mkdir " + temppath)
      Dir.exists?(temppath).should be_true
    end

    it "mkdir_p" do
      cmd.command("mkdir_p " + temppath + "/some/sub")
      Dir.exists?(temppath + "/some/sub").should be_true
    end

    it "symlink" do
      cmd.command("symlink test_file symlinked_file")
      File.symlink?("symlinked_file").should be_true
    end
  end

  FileUtils.rm_r path
end
