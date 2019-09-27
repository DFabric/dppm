require "../spec_helper"
require "../../src/prefix"

SPEC_CMD_PATH = spec_temp_prefix + "-cmd-test"

def spec_with_cmd(&block)
  spec_with_tempdir SPEC_CMD_PATH do |prefix|
    Dir.cd prefix do
      yield DPPM::Prefix::ProgramData::Task.new(Hash(String, String).new, Array(Path).new)
    end
  end
end

def spec_with_tempfile(&block : String ->)
  tempfile = File.tempfile prefix: "temp-dppm-file", suffix: nil
  begin
    yield tempfile.path
  ensure
    tempfile.delete
  end
end

describe DPPM::Prefix::ProgramData::Task do
  spec_with_cmd do |cmd|
    describe "command" do
      it "dir_current" do
        cmd.execute("dir_current").should eq Dir.current
      end

      it "ls" do
        spec_with_tempdir do |dir|
          filename = "test"
          file = (Path[dir] / filename).to_s
          File.touch file
          cmd.execute("ls " + dir).should eq filename
        end
      end

      describe "file_exists?" do
        it "file" { cmd.execute("file_exists? .").should eq "true" }
        it "directory" { cmd.execute("dir_exists? .").should eq "true" }
        it "false" { cmd.execute("file? .").should eq "false" }
      end

      describe "file? true" do
        it "file" do
          spec_with_tempfile do |file|
            cmd.execute("file? " + file).should eq "true"
          end
        end
        it "directory" { cmd.execute("file? " + SPEC_CMD_PATH).should eq "false" }
      end

      describe "dir_exists?" do
        it "file" do
          spec_with_tempfile do |file|
            cmd.execute("dir_exists? " + file).should eq "false"
          end
        end
        it "directory" { cmd.execute("dir_exists? " + Dir.current).should eq "true" }
      end

      it "cd" do
        Dir.cd Dir.current do
          spec_with_tempdir do |tempdir|
            cmd.execute("cd " + tempdir)
            Dir.current.should eq tempdir
          end
        end
      end

      it "cp" do
        spec_with_tempdir do |tempdir|
          source = (Path[tempdir] / "source").to_s
          dest = (Path[tempdir] / "dest").to_s
          File.write source, "data"
          cmd.execute("cp #{source} #{dest}")
          File.read(dest).should eq "data"
        end
      end

      it "mv" do
        File.write "test_file", "data"
        begin
          cmd.execute("mv test_file moved_file")
          File.read("moved_file").should eq "data"
        ensure
          File.delete "moved_file"
        end
      end

      it "rm" do
        tempfile = File.tempfile "dppm-"
        cmd.execute("rm " + tempfile.path)
        File.exists?(tempfile.path).should be_false
      end

      it "rm_r" do
        spec_with_tempdir do |tempdir|
          cmd.execute("rm_r " + tempdir)
          Dir.exists?(tempdir).should be_false
        end
      end

      it "mkdir" do
        tempdir = SPEC_CMD_PATH + "-cmd-test"
        begin
          cmd.execute("mkdir " + tempdir)
          Dir.exists?(tempdir).should be_true
        ensure
          Dir.rmdir tempdir
        end
      end

      it "mkdir_p" do
        spec_with_tempdir do |root_path|
          temppath = (Path[root_path] / "some" / "sub").to_s
          cmd.execute("mkdir_p " + temppath)
          Dir.exists?(temppath).should be_true
        end
      end

      it "symlink" do
        spec_with_tempdir do |root_path|
          source = (Path[root_path] / "source").to_s
          symlink = (Path[root_path] / "symlink").to_s
          File.touch source
          cmd.execute("symlink #{source} #{symlink}")
          File.symlink?(symlink).should be_true
          File.real_path(symlink).should eq source
        end
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
          pkg = CON.parse(%<[ "if file_exists? . == true" [ "cond = true" ] ]>).as_a
          cmd.run(pkg).should be_nil
          cmd.vars["cond"].should eq "true"
        end

        it "simple else" do
          pkg = CON.parse(%<[ "if file_exists? . != true" ["error"] "else" [ "cond = true" ] ]>).as_a
          cmd.run(pkg).should be_nil
          cmd.vars["cond"].should eq "true"
        end

        it "simple elif" do
          pkg = CON.parse(%<[ "if file_exists? . != true " ["error"] "elif file_exists? . == true" [ "cond = true" ] "else" ["error"] ]>).as_a
          cmd.run(pkg).should be_nil
          cmd.vars["cond"].should eq "true"
        end
      end
    end
  end
end
