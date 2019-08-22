require "../spec_helper"
require "../../src/prefix"

describe DPPM::Prefix::ProgramData::Task do
  path = Dir.current + "/cmd_test"
  temppath = path + "/command"
  Dir.mkdir path
  Dir.cd path
  File.write "test_file", "data"
  cmd = DPPM::Prefix::ProgramData::Task.new(Hash(String, String).new, Array(Path).new)

  describe "command" do
    it "current" do
      cmd.execute("current").should eq path
    end

    it "ls" do
      cmd.execute("ls .").should eq "test_file"
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
        cmd.execute("cd " + temppath)
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

    it "parses a quoted line as a string" do
      cmd.execute("'echo'").should eq "echo"
    end

    it "raises on unterminated quoted line" do
      ex = expect_raises(Exception) do
        cmd.execute "'echo"
      end
      ex.to_s.should eq "Unknown command or variable: 'echo"
    end
  end

  describe "Parse" do
    describe "variable" do
      it "raises on unterminated quoted line" do
        ex = expect_raises(Exception) do
          cmd.run CON.parse(%<["'echo"]>).as_a
        end
        ex.to_s.should eq "Error at line 1"
        ex.cause.to_s.should eq "Unknown command or variable: 'echo"
      end

      it "affect a string" do
        cmd.run CON.parse(%<["a = 'b'"]>).as_a
        cmd.vars["a"].should eq "b"
      end

      it "affect a command output" do
        cmd.run CON.parse(%<["b = readable? ."]>).as_a
        cmd.vars["b"].should eq "true"
      end

      it "uses interpolation" do
        cmd.run CON.parse(%<["c = '${dir}'"]>).as_a
        cmd.vars["c"].should eq Dir.current
      end
    end

    describe "condition" do
      it "simple if" do
        pkg = CON.parse(%<[ "if file_exists? . == true" [ "touch if_cond" ] ]>).as_a
        cmd.run(pkg).should be_nil
        File.exists?("if_cond").should be_true
      end

      it "simple else" do
        pkg = CON.parse(%<[ "if file_exists? . != true" ["error"] "else" [ "touch else_cond" ] ]>).as_a
        cmd.run(pkg).should be_nil
        File.exists?("else_cond").should be_true
      end

      it "simple elif" do
        pkg = CON.parse(%<[ "if file_exists? . != true " ["error"] "elif file_exists? . == true" [ "touch elif_cond" ] "else" ["error"] ]>).as_a
        cmd.run(pkg).should be_nil
        File.exists?("elif_cond").should be_true
      end
    end
  end
  Dir.cd __DIR__
  FileUtils.rm_r path
end
