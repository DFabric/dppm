require "./spec_helper"
require "../src/cmd"

describe Cmd::Run do
  path = Dir.current + "/cmd_test"
  temppath = path + "/command"
  Dir.mkdir path
  Dir.cd path
  File.write "test_file", "data"
  cmd = Cmd::Run.new(Hash(String, String).new)

  describe "command" do
    it "current" do
      cmd.execute("current").should eq path
    end

    it "ls" do
      cmd.execute("ls .").should eq ".\n..\ntest_file"
    end

    describe "file_exists?" do
      it "file" { cmd.execute("file_exists? test_file").should eq "true" }
      it "directory" { cmd.execute("file_exists? " + path).should eq "true" }
      it "false" { cmd.execute("file? " + path).should eq "false" }
    end

    describe "file? true" do
      it "file" { cmd.execute("file? test_file").should eq "true" }
      it "directory" { cmd.execute("file? " + path).should eq "false" }
    end

    describe "dir_exists?" do
      it "file" { cmd.execute("dir_exists? test_file").should eq "false" }
      it "directory" { cmd.execute("dir_exists? " + path).should eq "true" }
    end

    it "cd" do
      Dir.cd path do
        Dir.mkdir temppath
        cmd.execute("cd " + File.basename temppath)
        Dir.current.should eq temppath
        Dir.rmdir temppath
      end
    end

    it "cp" do
      cmd.execute("cp test_file other")
      File.read("other").should eq "data"
    end

    it "mv" do
      cmd.execute("mv test_file moved_file")
      File.read("moved_file").should eq "data"
    end

    it "rm" do
      File.write "test_rm", ""
      cmd.execute("rm test_rm")
      File.exists?("test_rm").should be_false
    end

    it "rm_r" do
      Dir.mkdir temppath
      cmd.execute("rm_r " + temppath)
      Dir.exists?(temppath).should be_false
    end

    it "mkdir" do
      cmd.execute("mkdir " + temppath)
      Dir.exists?(temppath).should be_true
    end

    it "mkdir_p" do
      cmd.execute("mkdir_p " + temppath + "/some/sub")
      Dir.exists?(temppath + "/some/sub").should be_true
    end

    it "symlink" do
      cmd.execute("symlink test_file symlinked_file")
      File.symlink?("symlinked_file").should be_true
    end
  end

  describe "variable" do
    it "affect a string" do
      cmd.run([YAML.parse %(a = "b")])
      cmd.@vars["a"].should eq "b"
    end

    it "affect a command output" do
      cmd.run([YAML.parse %(b = readable? .)])
      cmd.vars["b"].should eq "true"
    end

    it "uses interpolation" do
      cmd.run([YAML.parse %(c = "${dir}")])
      cmd.@vars["c"].should eq Dir.current
    end
  end

  describe "condition" do
    it "simple if" do
      cmd.run([YAML.parse "if file_exists? . == true: \n- touch if_cond"])
      File.exists?("if_cond").should be_true
    end

    it "simple else" do
      cmd.run([YAML.parse("if file_exists? . != true: \n- ls ."), YAML.parse("else: \n- touch else_cond")])
      File.exists?("else_cond").should be_true
    end

    it "simple elif" do
      cmd.run([YAML.parse("if file_exists? . != true: \n- ls ."), YAML.parse("if file_exists? . == true: \n- touch elif_cond")])
      File.exists?("elif_cond").should be_true
    end
  end

  FileUtils.rm_r path
end
