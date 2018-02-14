module Cmd
  def self.find_bin(pkgdir, cmd)
    Dir[pkgdir + "bin", pkgdir + "lib/*/bin"].each do |path|
      return path + '/' + cmd if File.executable? path + '/' + cmd
    end
    ""
  end

  struct Run
    getter vars = Hash(String, String).new
    getter extvars = Hash(String, String).new

    def initialize(yaml : Array, vars = Hash(String, String).new, &@log : String, String, String -> Nil)
      Dir.cd vars["pkgdir"]
      # Create a PATH variable
      run yaml, vars.map { |k, v| [k.upcase, v] }.to_h
    end

    def run(yaml : Array, @vars = Hash(String, String).new)
      vars.map { |k, v| extvars["${" + k + '}'] = v }
      # End of block
      last_cond = false

      yaml.each do |line|
        begin
          # Add/change vars
          if line.is_a? String
            if line =~ /^([a-zA-Z0-9_]+) = (.*)/
              @vars[$1] = command($2).to_s
              @extvars["${" + $1 + '}'] = @vars[$1]
            elsif line[0..3] == "echo"
              @log.call "INFO", "echo", var(line[5..-1]) + '\n'
            else
              cmd = var line
              @log.call "INFO", "execute", cmd
              output = command cmd
              @log.call "INFO", "output ", command(cmd).to_s if output != nil && output != 0
            end
            # New condition block
          elsif line.is_a? Hash
            if line.first_key.to_s[0..3] == "elif" && last_cond
              # Previous if/elif is true
            elsif cond(var(line.first_key).to_s, last_cond) || (line.first_key.to_s == "else" && !last_cond)
              line.not_nil!.each_value do |subline|
                run subline.not_nil!, vars if subline.is_a? Array
              end
              last_cond = true
            else
              last_cond = false
            end
          else
            raise "unknown line"
          end
        rescue ex
          raise "`#{line}` execution failed: #{ex}"
        end
      end
    end

    private def var(cmd)
      # Check if variables in the command are defined
      cmd.to_s.scan(/(?<!\\)\${[a-zA-Z0-9_]+}/).each do |var|
        raise "unknown variable: " + var[0] if !extvars[var[0]]?
      end

      # Replace vars by their values
      cmd.to_s.gsub(/(?<!\\)\${([a-zA-Z0-9_]+)}/, extvars)
              # Remove a slash for escpaded vars
              .gsub(/\\(\${[a-zA-Z0-9_]+})/, "\\1")
    end

    private def cond(expr, last_cond)
      case expr.split(' ')[0]
      when "if"    then ifexpr expr.[3..-1]
      when "elif"  then ifexpr expr.[5..-1] if !last_cond
      when !"else" then raise "unknown condition: " + expr.split(' ')[0]
      end
    end

    private def ifexpr(expr)
      expr.split(" || ") do |block|
        case block
        when "true" then return true
          # Variable existence
        when /^\!([a-zA-Z0-9_]+)\?/
          return true if !vars[$1]?
        when /^([a-zA-Z0-9_]+)\?/
          return true if vars[$1]?
        when /^([a-zA-Z0-9_]+) != (.*)/
          if vars[$1]?
            return true if vars[$1] != $2
          elsif vars[$2]?
            return true if vars[$2] != $1
          else
            raise "variables called but neither of `#{$1}` nor `#{$2}` are already known"
          end
        when /^([a-zA-Z0-9_]+) = (.*)/
          if vars[$1]?
            return true if vars[$1] == $2
          elsif vars[$2]?
            return true if vars[$2] == $1
          else
            raise "variables called but neither of `#{$1}` nor `#{$2}` are already known"
          end
        end
      end
    end

    # Methods from
    # https://crystal-lang.org/api/DIr.html
    # https://crystal-lang.org/api/File.html
    private def command(cmdline)
      # Check if it's a variable
      if cmdline =~ /^"(.*)"$/
        return var $1
      elsif vars[cmdline]?
        return vars[cmdline]
      end
      cmd = cmdline.split(' ')
      case cmd[0]
      when /^\/.*/ then execute cmd[0], cmd[1..-1]
        # use globs while executing a command
      when "glob"
        cmd1 = cmd[1]
        if cmd[3]?
          dir = cmd[3]
          Dir[cmd[2]].each { |entry| command cmd1 + ' ' + entry + ' ' + dir + '/' + File.basename entry }
        else
          Dir[cmd[2]].each { |entry| command cmd1 + ' ' + entry }
        end
      when "current" then Dir.current
        # Booleans
      when "empty_d?"  then Dir.empty? cmdline[9..-1]
      when "empty_f?"  then File.empty? cmdline[9..-1]
      when "exists_f?" then File.exists? cmdline[10..-1]
      when "exists_d?" then Dir.exists? cmdline[10..-1]
      when "file?"     then File.file? cmdline[6..-1]
        # Single arugment
      when "cd"          then Dir.cd cmdline[3..-1]
      when "mkdir"       then FileUtils.mkdir cmd[1..-1]
      when "mkdir_p"     then FileUtils.mkdir_p cmd[1..-1]
      when "mv"          then cmd[3]? ? FileUtils.mv(cmd[1..-2], cmd[-1]) : File.rename cmd[1], cmd[2]
      when "rmdir"       then FileUtils.rmdir cmd[1..-1]
      when "rm"          then FileUtils.rm cmd[1..-1]
      when "rm_r"        then FileUtils.rm_r cmd[1..-1]
      when "rm_rf"       then FileUtils.rm_rf cmd[1..-1]
      when "entries"     then Dir.entries cmdline[3..-1]
      when "dirname"     then File.dirname cmdline[8..-1]
      when "read"        then File.read cmdline[5..-1]
      when "size"        then File.size cmdline[5..-1]
      when "touch"       then File.touch cmdline[6..-1]
      when "readable?"   then File.readable? cmdline[10..-1]
      when "writable?"   then File.writable? cmdline[10..-1]
      when "expand_path" then File.expand_path cmdline[12..-1]
      when "real_path"   then File.real_path cmdline[10..-1]
        # Double argument with space separator
      when "cp"      then FileUtils.cp cmd[1], cmd[2]
      when "cp_r"    then FileUtils.cp_r cmd[1], cmd[2]
      when "link"    then File.link cmd[1], cmd[2]
      when "symlink" then File.symlink cmd[1], cmd[2]
      when "write"   then File.write cmd[1], cmd[2]
      when "chmod"   then File.chmod cmd[1], cmd[2].to_i(8)
      when "chown"   then File.chown cmd[1], Owner.to_id(cmd[2], "uid"), Owner.to_id(cmd[3], "gid")
        # Custom
      when "ls"                     then Dir.entries Dir.current
      when "get"                    then ConfFile.get cmd[1], Utils.to_array(cmd[2])
      when "del"                    then ConfFile.del cmd[1], Utils.to_array(cmd[2])
      when "set"                    then ConfFile.set cmd[1], Utils.to_array(cmd[2]), cmd[3..-1].join(' ')
      when /^(json|yaml|ini)\.get$/ then ConfFile.get cmd[1], Utils.to_array(cmd[2]), $1
      when /^(json|yaml|ini)\.del$/ then ConfFile.del cmd[1], Utils.to_array(cmd[2]), $1
      when /^(json|yaml|ini)\.set$/ then ConfFile.set cmd[1], Utils.to_array(cmd[2]), cmd[3..-1].join(' '), $1
      when "chmod_r"                then Utils.chmod_r cmd[1], cmd[2].to_i(8)
      when "chown_r"                then Utils.chown_r cmd[3], Owner.to_id(cmd[1], "uid"), Owner.to_id(cmd[2], "gid")
        # Download
      when "getstring" then HTTPget.string cmd[1]
      when "getfile"
        file = cmd[2]? ? cmd[2] : File.basename cmd[1]
        HTTPget.file cmd[1], file
        # Compression
      when "unzip"     then execute "/bin/unzip", ["-oq", cmd[1], "-d", cmd[2]]
      when "untar_bz2" then execute "/bin/tar", ["jxf", cmd[1], "-C", cmd[2]]
      when "untar_gz"  then execute "/bin/tar", ["zxf", cmd[1], "-C", cmd[2]]
      when "untar_lz"  then execute "/bin/tar", ["axf", cmd[1], "-C", cmd[2]]
      when "untar_xz"  then execute "/bin/tar", ["Jxf", cmd[1], "-C", cmd[2]]
      when "exit"
        puts "exit called, exiting."
        exit 1
      else
        # check if the command is available in `bin` of the package and dependencies
        bin = Cmd.find_bin vars["PKGDIR"], cmd[0]
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
      command.empty? ? nil : command
    end
  end
end
