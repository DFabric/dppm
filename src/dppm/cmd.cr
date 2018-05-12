module Cmd
  def self.find_bin(pkgdir, cmd)
    Dir[pkgdir + "/bin", pkgdir + "/lib/*/bin"].each do |path|
      return "#{path}/#{cmd}" if File.executable? "#{path}/#{cmd}"
    end
    ""
  end

  class Run
    @extvars = Hash(String, String).new

    def initialize(@vars : Hash(String, String))
      # Create a PATH variable
      @vars = @vars.map { |k, v| [k.upcase, v] }.to_h
      @vars.each { |k, v| @extvars["${#{k}}"] = v }
    end

    def run(yaml : Array)
      cmd = ""
      # End of block
      last_cond = false

      yaml.each do |line|
        # Add/change vars
        case line
        when .is_a? String
          # New variable assignation
          if (line_var = line.split(" = ")) && line_var[0].ascii_alphanumeric_underscore?
            @vars[line_var[0]] = @extvars["${#{line_var[0]}}"] = command(line_var[1])
            # Print string
          elsif line[0..3] == "echo"
            Log.info "echo", "#{command(var(line[5..-1]))}\n"
          else
            cmd = var line
            Log.info "execute", cmd
            output = command cmd
            Log.info "output", output if !output.empty?
          end
          # New condition block
        when .is_a? Hash
          if line.first_key.to_s[0..3] == "elif" && last_cond
            # Previous if/elif is true
          elsif cond(var(line.first_key).to_s, last_cond) || (line.first_key.to_s == "else" && !last_cond)
            line.each_value do |subline|
              run subline if subline.is_a? Array
            end
            last_cond = true
          else
            last_cond = false
          end
        else
          raise "unknown line: #{line}"
        end
      rescue ex
        raise "`#{!cmd.empty? ? cmd : line}` execution failed: #{ex}"
      end
    end

    private def var(cmd)
      # Check if variables in the command are defined
      cmd.to_s.scan(/(?<!\\)\${[a-zA-Z0-9_]+}/).each do |var|
        raise "unknown variable: " + var[0] if !@extvars[var[0]]?
      end

      # Replace vars by their values
      cmd.to_s.gsub(/(?<!\\)\${([a-zA-Z0-9_]+)}/, @extvars)
              # Remove a slash for escpaded vars
              .gsub(/\\(\${[a-zA-Z0-9_]+})/, "\\1")
    end

    private def cond(expr, last_cond)
      case name = expr.split(' ', limit: 2).first
      when "if"    then ifexpr expr[3..-1]
      when "elif"  then ifexpr expr[5..-1] if !last_cond
      when !"else" then raise "unknown condition: " + name
      end
    end

    private def ifexpr(expr)
      expr.split(" || ") do |block|
        case block
        when "true"  then return true
        when "false" then return false
        when .ascii_alphanumeric_underscore?
          if block.starts_with? '!'
            return true if !@vars[block.lchop]?
          else
            return true if @vars[block.lchop]?
          end
        else
          vars = block.split(" == ", 2)
          return command(vars[0]) == command(vars[1]) if vars[1]?
          vars = block.split(" != ", 2)
          return command(vars[0]) != command(vars[1]) if vars[1]?
        end
      end
      false
    end

    # Methods from
    # https://crystal-lang.org/api/Dir.html
    # https://crystal-lang.org/api/File.html
    def command(cmdline)
      # Check if it's a variable
      if cmdline.starts_with?('"') && cmdline.starts_with?('"')
        return var cmdline[1..-2]
      elsif @vars[cmdline]?
        return @vars[cmdline]
      end

      cmd = cmdline.split ' '
      case cmd[0]
      when cmdline.starts_with? '/' then execute cmd[0], cmd[1..-1]
        # use globs while executing a command
      when "glob"
        cmd1 = cmd[1]
        if dir = cmd[3]?
          Dir[cmd[2]].each { |entry| command "#{cmd1} #{entry} #{dir}/#{File.basename entry}" }
        else
          Dir[cmd[2]].each { |entry| command "#{cmd1} #{entry}" }
        end
        ""
      when "current" then Dir.current
        # Booleans
      when "dir_empty?"   then Dir.empty?(cmdline[9..-1]).to_s
      when "dir_exists?"  then Dir.exists?(cmdline[12..-1]).to_s
      when "file_empty?"  then File.empty?(cmdline[12..-1]).to_s
      when "file_exists?" then File.exists?(cmdline[13..-1]).to_s
      when "file?"        then File.file?(cmdline[6..-1]).to_s
        # Single arugment
      when "cd"          then Dir.cd cmdline[3..-1]; "working directory moved"
      when "mkdir"       then FileUtils.mkdir cmd[1..-1]; "directory created"
      when "mkdir_p"     then FileUtils.mkdir_p cmd[1..-1]; "directory created"
      when "mv"          then cmd[3]? ? FileUtils.mv(cmd[1..-2], cmd[-1]) : File.rename cmd[1], cmd[2]; "file moved"
      when "rmdir"       then FileUtils.rmdir cmd[1..-1]; "directory removed"
      when "rm"          then FileUtils.rm cmd[1..-1]; "file removed"
      when "rm_r"        then FileUtils.rm_r cmd[1..-1]; "directory removed"
      when "rm_rf"       then FileUtils.rm_rf cmd[1..-1]; "directory removed"
      when "dirname"     then File.dirname cmdline[8..-1]
      when "read"        then File.read cmdline[5..-1]
      when "size"        then File.size(cmdline[5..-1]).to_s
      when "touch"       then File.touch cmdline[6..-1]; "file created/updated"
      when "readable?"   then File.readable?(cmdline[10..-1]).to_s
      when "symlink?"    then File.symlink?(cmdline[9..-1]).to_s
      when "writable?"   then File.writable?(cmdline[10..-1]).to_s
      when "expand_path" then File.expand_path cmdline[12..-1]
      when "real_path"   then File.real_path cmdline[10..-1]
        # Double argument with space separator
      when "append"  then File.open cmd[1], "a", &.print Utils.to_type(cmd[2..-1].join(' ')); "text appended"
      when "cp"      then FileUtils.cp cmd[1], cmd[2]; "file copied"
      when "cp_r"    then FileUtils.cp_r cmd[1], cmd[2]; "directory copied"
      when "link"    then File.link cmd[1], cmd[2]; "hard link created"
      when "symlink" then File.symlink cmd[1], cmd[2]; "symbolic link created"
      when "write"   then File.write cmd[1], Utils.to_type(cmd[2..-1].join(' ')); "text written"
      when "chmod"   then File.chmod cmd[1], cmd[2].to_i(8); "permissions changed"
      when "chown" then File.chown cmd[1], Owner.to_id(cmd[2], "uid"), Owner.to_id(cmd[3], "gid"); "owner changed"
      # Custom


      when "dir" then Dir.current
      when "ls"
        directory = cmdline[3..-1]
        directory = Dir.current if directory.empty?
        Dir.entries(directory).join('\n')
      when "get"              then ConfFile.get(cmd[1], Utils.to_array(cmd[2])).to_s
      when "del"              then ConfFile.del(cmd[1], Utils.to_array(cmd[2])).to_s
      when "set"              then ConfFile.set(cmd[1], Utils.to_array(cmd[2]), cmd[3..-1].join(' ')).to_s
      when .ends_with? ".get" then ConfFile.get(cmd[1], Utils.to_array(cmd[2]), cmd[0][0..-5]).to_s
      when .ends_with? ".del" then ConfFile.del(cmd[1], Utils.to_array(cmd[2]), cmd[0][0..-5]).to_s
      when .ends_with? ".set" then ConfFile.set(cmd[1], Utils.to_array(cmd[2]), cmd[3..-1].join(' '), cmd[0][0..-5]).to_s
      when "chmod_r"          then Utils.chmod_r cmd[1], cmd[2].to_i(8); "permissions changed"
      when "chown_r" then Utils.chown_r cmd[3], Owner.to_id(cmd[1], "uid"), Owner.to_id(cmd[2], "gid"); "owner changed"
      # Download


      when "getstring" then HTTPget.string cmd[1]
      when "getfile"
        file = cmd[2]? ? cmd[2] : File.basename cmd[1]
        HTTPget.file cmd[1], file
        "file retrieved"
        # Compression
      when "unzip"     then execute "/bin/unzip", ["-oq", cmd[1], "-d", cmd[2]]; "zip archive extracted"
      when "untar_bz2" then execute "/bin/tar", ["jxf", cmd[1], "-C", cmd[2]]; "bzip2 archive extracted"
      when "untar_gz"  then execute "/bin/tar", ["zxf", cmd[1], "-C", cmd[2]]; "gzip archive extracted"
      when "untar_lz"  then execute "/bin/tar", ["axf", cmd[1], "-C", cmd[2]]; "lz archive extracted"
      when "untar_xz"  then execute "/bin/tar", ["Jxf", cmd[1], "-C", cmd[2]]; "xz archive extracted"
      when "true"      then "true"
      when "false"     then "false"
      when "exit"
        puts "exit called, exiting."; exit 1
        # System executable
      when .starts_with? '/' then execute cmd[0], cmd[1..-1]
      else
        # check if the command is available in `bin` of the package and dependencies
        bin = Cmd.find_bin @vars["PKGDIR"], cmd[0]
        if bin.empty?
          raise "unknown command or variable: " + cmdline
        else
          execute bin, cmd[1..-1]
        end
      end
    end

    private def execute(bin, array)
      # Use the system `tar`, for now
      command = Exec.new(bin, array).out
      command.empty? ? "" : command
    end
  end
end
