require "exec"
require "./config"
require "./httpget"

module Cmd
  def self.find_bin(pkgdir, cmd)
    path = "#{pkgdir}/bin/#{cmd}"
    return path if File.executable? path

    Dir.each_child(pkgdir + "/lib") do |library|
      path = "#{pkgdir}/lib/#{library}/bin/#{cmd}"
      return path if File.executable? path
    end
  end

  struct Run
    getter vars : Hash(String, String)

    def initialize(@vars : Hash(String, String))
      # Create a PATH variable
      @vars = @vars.map { |k, v| [k.upcase, v] }.to_h
    end

    def run(yaml : Array)
      cmd = ""
      # End of block
      last_cond = false

      yaml.each do |raw_line|
        # Add/change vars
        if line = raw_line.as_s?
          # New variable assignation
          if line.size > 4 && (line_var = line.split(" = ", limit: 2)) && (first_line_var = line_var[0]) && Utils.ascii_alphanumeric_underscore? first_line_var
            @vars[first_line_var] = execute(line_var[1])
            # Print string
          elsif line.starts_with? "echo"
            Log.info "echo", "#{execute(var_reader(line[5..-1]))}\n"
          else
            cmd = var_reader line
            Log.info "execute", cmd
            output = execute cmd
            Log.info "output", output if !output.empty?
          end
          # New condition block
        elsif line = raw_line.as_h?
          first_key = line.first_key.to_s
          if first_key.starts_with?("elif") && last_cond
            # Previous if/elif is true
          elsif cond(var_reader(first_key), last_cond) || (first_key == "else" && !last_cond)
            line.each_value do |subline|
              if array = subline.as_a?
                run array
              end
            end
            last_cond = true
          else
            last_cond = false
          end
        else
          raise "unknown line: #{line}"
        end
      rescue ex
        raise "`#{!cmd.empty? ? cmd : line}` - execution failed:\n#{ex}"
      end
    end

    private def var_reader(cmd : String)
      # Check if variables in the command are defined
      escape = false
      building_command = false
      command = IO::Memory.new
      reader = Char::Reader.new cmd
      String.build do |str|
        while reader.has_next?
          if escape
            str << reader.current_char
            escape = false
          else
            case char = reader.current_char
            when '\\' then escape = true
            when '$'
              if reader.peek_next_char == '{'
                building_command = true
                reader.next_char
              else
                str << char
              end
            when '}'
              if building_command
                str << execute command.to_s
                building_command = false
                command.clear
              else
                str << char
              end
            else
              if building_command
                command << char
              else
                str << char
              end
            end
          end
          reader.next_char
        end
        str << command
      end
    end

    private def cond(expr, last_cond)
      line = expr.split(' ', limit: 2)
      case line[0]
      when "if"    then ifexpr line[1]
      when "elif"  then ifexpr line[1] if !last_cond
      when !"else" then raise "unknown condition: " + line[0]
      end
    end

    private def ifexpr(expr)
      expr.split(" || ") do |block|
        if Utils.ascii_alphanumeric_underscore? block
          if block.starts_with? '!'
            return !@vars[block.lchop]?
          else
            return @vars[block.lchop]?
          end
        else
          case block
          when "true"  then return true
          when "false" then return false
          else
            vars = block.split(" == ", 2)
            if second_var = vars[1]?
              return execute(vars[0]) == execute(second_var)
            end
            vars = block.split(" != ", 2)
            if second_var = vars[1]?
              return execute(vars[0]) != execute(second_var)
            end
          end
        end
      end
      false
    end

    # Methods from
    # https://crystal-lang.org/api/Dir.html
    # https://crystal-lang.org/api/File.html
    def execute(cmdline)
      # Check if it's a variable
      if cmdline.starts_with?('"') && cmdline.starts_with?('"')
        return var_reader cmdline[1..-2]
      elsif variable = @vars[cmdline]?
        return variable
      end

      cmd = cmdline.split ' '
      case command = cmd[0]
      when cmdline.starts_with? '/' then Exec.new(command, cmd[1..-1]).out
        # use globs while executing a command
      when "glob"
        if dir = cmd[3]?
          Dir[cmd[2]].each { |entry| execute "#{cmd[1]} #{entry} #{dir}/#{File.basename entry}" }
        else
          Dir[cmd[2]].each { |entry| execute cmd[1] + ' ' + entry }
        end
        ""
      when "current" then Dir.current
        # Booleans
      when "dir_empty?"   then Dir.empty?(cmdline[9..-1]).to_s
      when "dir_exists?"  then Dir.exists?(cmdline[12..-1]).to_s
      when "file_empty?"  then File.empty?(cmdline[12..-1]).to_s
      when "file_exists?" then File.exists?(cmdline[13..-1]).to_s
      when "file?"        then File.file?(cmdline[6..-1]).to_s
      when "root_user?"   then ::System::Owner.root?.to_s
        # Single arugment
      when "cd"            then Dir.cd cmdline[3..-1]; "working directory moved"
      when "mkdir"         then FileUtils.mkdir cmd[1..-1]; "directory created"
      when "mkdir_p"       then FileUtils.mkdir_p cmd[1..-1]; "directory created"
      when "mv"            then cmd[3]? ? FileUtils.mv(cmd[1..-2], cmd[-1]) : File.rename cmd[1], cmd[2]; "file moved"
      when "rmdir"         then FileUtils.rmdir cmd[1..-1]; "directory removed"
      when "rm"            then FileUtils.rm cmd[1..-1]; "file removed"
      when "rm_r"          then FileUtils.rm_r cmd[1..-1]; "directory removed"
      when "rm_rf"         then FileUtils.rm_rf cmd[1..-1]; "directory removed"
      when "dirname"       then File.dirname cmdline[8..-1]
      when "read"          then File.read cmdline[5..-1]
      when "file_size"     then File.size(cmdline[5..-1]).to_s
      when "touch"         then File.touch cmdline[6..-1]; "file created/updated"
      when "readable?"     then File.readable?(cmdline[10..-1]).to_s
      when "symlink?"      then File.symlink?(cmdline[9..-1]).to_s
      when "writable?"     then File.writable?(cmdline[10..-1]).to_s
      when "expand_path"   then File.expand_path cmdline[12..-1]
      when "real_path"     then File.real_path cmdline[10..-1]
      when "random_base64" then Random::Secure.urlsafe_base64(cmd[1].to_i).to_s
        # Double argument with space separator
      when "append"  then File.open cmd[1], "a", &.print Utils.to_type(cmd[2..-1].join(' ')); "text appended"
      when "cp"      then FileUtils.cp cmd[1], cmd[2]; "file copied"
      when "cp_r"    then FileUtils.cp_r cmd[1], cmd[2]; "directory copied"
      when "link"    then File.link cmd[1], cmd[2]; "hard link created"
      when "symlink" then File.symlink cmd[1], cmd[2]; "symbolic link created"
      when "write"   then File.write cmd[1], Utils.to_type(cmd[2..-1].join(' ')); "text written"
      when "chmod"   then File.chmod cmd[1], cmd[2].to_i(8); "permissions changed"
      when "chown" then File.chown cmd[1], ::System::Owner.to_uid(cmd[2]), ::System::Owner.to_gid(cmd[3]); "owner changed"
      # Custom
      when "dir" then Dir.current
      when "ls"
        directory = cmd[1]? || Dir.current
        Dir.entries(directory).join '\n'
      when "get"              then Config.new(cmd[1]).get(cmd[2]).to_s
      when "del"              then Config.new(cmd[1]).del(cmd[2]).to_s
      when "set"              then Config.new(cmd[1]).set(cmd[2], cmd[3..-1].join(' ')).to_s
      when .ends_with? ".get" then Config.new(cmd[1], command[0..-5]).get(cmd[2]).to_s
      when .ends_with? ".del" then Config.new(cmd[1], command[0..-5]).del(cmd[2]).to_s
      when .ends_with? ".set" then Config.new(cmd[1], command[0..-5]).set(cmd[2], cmd[3..-1].join(' ')).to_s
      when "chmod_r"          then Utils.chmod_r cmd[1], cmd[2].to_i(8); "permissions changed"
      when "chown_r" then Utils.chown_r cmd[3], ::System::Owner.to_uid(cmd[1]), ::System::Owner.to_gid(cmd[2]); "owner changed"
      # Download
      when "getstring" then HTTPget.string cmd[1]
      when "getfile"
        url = cmd[1]
        file = cmd[2]? || File.basename url
        HTTPget.file url, file
        "file retrieved"
        # Compression
        # Use the system `tar` and `unzip` for now
      when "unzip"     then Exec.new("/usr/bin/unzip", ["-oq", cmd[1], "-d", cmd[2]]); "zip archive extracted"
      when "untar_bz2" then Exec.new("/bin/tar", ["jxf", cmd[1], "-C", cmd[2]]); "bzip2 archive extracted"
      when "untar_gz"  then Exec.new("/bin/tar", ["zxf", cmd[1], "-C", cmd[2]]); "gzip archive extracted"
      when "untar_lz"  then Exec.new("/bin/tar", ["axf", cmd[1], "-C", cmd[2]]); "lz archive extracted"
      when "untar_xz"  then Exec.new("/bin/tar", ["Jxf", cmd[1], "-C", cmd[2]]); "xz archive extracted"
      when "exit"      then puts "exit called, exiting."; exit 1
      when "true"      then "true"
      when "false"     then "false"
      else
        # check if the command is available in `bin` of the package and dependencies
        if bin = Cmd.find_bin(@vars["PKGDIR"], command) || Process.find_executable(command)
          Exec.new(bin, cmd[1..-1]).out
        else
          raise "unknown command or variable: #{cmd}"
        end
      end
    end
  end
end
