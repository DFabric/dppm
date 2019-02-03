require "con"

struct Manager::Cmd
  getter vars : Hash(String, String) = Hash(String, String).new
  @line_number : Int32 = 0

  def initialize(vars : Hash(String, String))
    @vars = vars.transform_keys &.upcase
  end

  def self.find_bin(pkgdir, cmd)
    path = "#{pkgdir}/bin/#{cmd}"
    return path if File.executable? path

    Dir.each_child(pkgdir + "/lib") do |library|
      path = "#{pkgdir}/lib/#{library}/bin/#{cmd}"
      return path if File.executable? path
    end
  end

  def run(commands_array : Array)
    # End of block
    last_cond = false

    commands_array.each do |raw_line|
      # # Add/change vars
      if line = raw_line.as_s?
        @line_number += 1
        # # New variable assignation
        if line.size > 4 &&
           (line_var = line.split(" = ", limit: 2)) &&
           (first_line_var = line_var[0]) &&
           Utils.ascii_alphanumeric_underscore? first_line_var
          if (output = execute(line_var[1])).is_a? String
            @vars[first_line_var] = output
          else
            raise "expected String, got #{output}"
          end
        else
          cmd = var_reader line
          Log.info "execute", cmd
          case output = execute cmd, last_cond
          when String then Log.info "output", output if !output.empty?
          when Bool   then last_cond = output
          else             raise "invalid output: #{output}"
          end
        end
      elsif last_cond
        if array = raw_line.as_a?
          run array
        else
          raise "expected Array"
        end
      end
    rescue ex
      raise Exception.new "error at line #{@line_number}:\n#{ex}", ex
    end
  end

  private def var_reader(cmd : String)
    # Check if variables in the command are defined
    building_command = false
    command = IO::Memory.new
    reader = Char::Reader.new cmd
    String.build do |str|
      while reader.has_next?
        case char = reader.current_char
        when '\\' then str << reader.next_char
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
        reader.next_char
      end
      str << command
    end
  end

  def ascii_alphanumeric_underscore?(string : String)
    string.each_char { |char| char.ascii_letter? || char.ascii_number? || char == '_' || return }
    true
  end

  private def ifexpr(expr) : Bool
    expr.split(" || ").each do |block|
      case block
      when "true"  then return true
      when "false" then return false
      else
        if block.starts_with?('!') && ascii_alphanumeric_underscore? block.lchop
          return !@vars.has_key? block.lchop
        elsif ascii_alphanumeric_underscore? block
          return @vars.has_key? block
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
  def execute(cmdline : String, last_cond : Bool = false) : String | Bool
    # Check if it's a variable
    if cmdline.starts_with?('\'') && cmdline.starts_with?('\'')
      return var_reader cmdline[1..-2]
    elsif variable = @vars[cmdline]?
      return variable
    end

    cmd = cmdline.split ' '
    case command = cmd[0]
    when "if"                     then ifexpr cmdline[3..-1]
    when "elif"                   then last_cond ? false : ifexpr(cmdline[5..-1])
    when "else"                   then !last_cond
    when cmdline.starts_with? '/' then Manager.exec command, cmd[1..-1]
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
    when "root_user?"   then Process.root?.to_s
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
    when "chmod" then File.chmod cmd[1], cmd[2].to_i(8); "permissions changed"
    # Custom
    when "dir" then Dir.current
    when "ls"
      directory = cmd[1]? || Dir.current
      Dir.entries(directory).join '\n'
    when "get" then Config.new(cmd[1]).get(cmd[2]).to_s
    when "del"
      config = Config.new(cmd[1])
      result = config.del(cmd[2]).to_s
      config.write
      result
    when "set"
      config = Config.new(cmd[1])
      result = config.set(cmd[2], cmd[3..-1].join(' ')).to_s
      config.write
      result
    when "chmod_r" then Utils.chmod_r cmd[1], cmd[2].to_i(8); "permissions changed"
    # Download
    when "getstring" then HTTPHelper.get_string cmd[1]
    when "getfile"
      url = cmd[1]
      file = cmd[2]? || File.basename url
      HTTPHelper.get_file url, file
      "file retrieved"
      # Compression
      # Use the system `tar` and `unzip` for now
    when "unzip"     then Manager.exec "/usr/bin/unzip", {"-oq", cmd[1], "-d", cmd[2]}; "zip archive extracted"
    when "untar_bz2" then Manager.exec "/bin/tar", {"jxf", cmd[1], "-C", cmd[2]}; "bzip2 archive extracted"
    when "untar_gz"  then Manager.exec "/bin/tar", {"zxf", cmd[1], "-C", cmd[2]}; "gzip archive extracted"
    when "untar_lz"  then Manager.exec "/bin/tar", {"axf", cmd[1], "-C", cmd[2]}; "lz archive extracted"
    when "untar_xz"  then Manager.exec "/bin/tar", {"Jxf", cmd[1], "-C", cmd[2]}; "xz archive extracted"
    when "exit"      then Log.info "exit called", "exiting."; exit 1
    when "error"     then raise cmdline[4..-1].lstrip
    when "true"      then "true"
    when "false"     then "false"
    when "puts"      then cmdline[3..-1].lstrip
    else
      # check if the command is available in `bin` of the package and dependencies
      if bin = Cmd.find_bin(@vars["BASEDIR"], command) || Process.find_executable(command)
        Manager.exec bin, cmd[1..-1]
        "success"
      else
        raise "unknown command or variable: #{cmd}"
      end
    end
  end
end
