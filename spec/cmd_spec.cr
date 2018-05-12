require "./spec_helper"

describe Cmd::Run do
  path = Dir.current + "/cmd_test"
  temppath = path + "/command"
  Dir.mkdir path
  Dir.cd path
  File.write "test_file", "data"
  cmd = Cmd::Run.new(Hash(String, String).new)

  describe "command" do
    it "current" do
      cmd.command("current").should eq path
    end

    it "ls" do
      cmd.command("ls .").should eq ".\n..\ntest_file"
    end

    describe "file_exists?" do
      it "file" { cmd.command("file_exists? test_file").should eq "true" }
      it "directory" { cmd.command("file_exists? " + path).should eq "true" }
      it "false" { cmd.command("file? " + path).should eq "false" }
    end

    describe "file? true" do
      it "file" { cmd.command("file? test_file").should eq "true" }
      it "directory" { cmd.command("file? " + path).should eq "false" }
    end

    describe "dir_exists?" do
      it "file" { cmd.command("dir_exists? test_file").should eq "false" }
      it "directory" { cmd.command("dir_exists? " + path).should eq "true" }
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

  describe "condtions" do
    it "simple if condition" do
      cmd.run([{"if file_exists? . == true" => ["touch if_cond"]}])
      File.exists?("if_cond").should be_true
    end

    it "simple else condition" do
      cmd.run([{"if file_exists? . != true" => ["ls ."]}, {"else" => ["touch else_cond"]}])
      File.exists?("else_cond").should be_true
    end

    it "simple elif condition" do
      cmd.run([{"if file_exists? . != true" => ["ls ."]}, {"if file_exists? . == true" => ["touch elif_cond"]}])
      File.exists?("elif_cond").should be_true
    end
  end

  FileUtils.rm_r path
end
