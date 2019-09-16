require "con"

struct DPPM::Prefix::ProgramData::Task
  getter vars : Hash(String, String) = Hash(String, String).new
  @line_number : Int32 = 0

  # Creates a new task runtime with variables and paths where to search binaries.
  def initialize(vars : Hash(String, String), @all_bin_paths : Array(Path))
    @vars = vars.transform_keys &.upcase
  end

  # Returns the first executable matching `cmd` in .
  def executable?(cmd : String) : String?
    @all_bin_paths.each do |path|
      bin = path / cmd
      return bin.to_s if File.executable? bin.to_s
    end
  end

  # Run the commands.
  def run(commands_array : Array)
    # End of block
    last_cond = false

    commands_array.each do |raw_line|
      # # Add/change vars
      if line = raw_line.as_s?
        @line_number += 1
        # # New variable assignation
        if !assign_variable? line
          cmd = var_reader line
          Log.info "execute", cmd
          case output = execute cmd, last_cond
          when String then Log.info "output", output if !output.empty?
          when Bool   then last_cond = output
          else             raise "Invalid output: #{output}"
          end
        end
      elsif last_cond
        if array = raw_line.as_a?
          run array
        else
          raise "Expected Array"
        end
      end
    end
  rescue ex
    raise Exception.new "Error at line #{@line_number}", ex
  end

  # Assigns a value to a variable from a line string if it corresponds to an assignment.
  private def assign_variable?(line : String) : String?
    return if line.size < 5
    var, _, value = line.partition(" = ")
    return if !Utils.ascii_alphanumeric_underscore? var
    if (output = execute value).is_a? String
      @vars[var] = output
    else
      raise "Expected String, got #{output}"
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
  # https://crystal-lang.org/api/Dir.html and
  # https://crystal-lang.org/api/File.html
  #
  # ameba:disable Metrics/CyclomaticComplexity
  def execute(cmdline : String, last_cond : Bool = false) : String | Bool
    # Check if it's a variable
    if line = cmdline.lchop?('\'').try &.rchop?('\'')
      return var_reader line
    elsif variable = @vars[cmdline]?
      return variable
    end

    cmd = cmdline.split ' '
    command = cmd[0]
    arguments = cmdline.lchop(command).lchop
    case command = cmd[0]
    when "if"              then ifexpr arguments
    when "elif"            then last_cond ? false : ifexpr(arguments)
    when "else"            then !last_cond
    when .starts_with? '/' then Host.exec command, cmd[1..-1]
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
    when "dir_empty?"   then Dir.empty?(arguments).to_s
    when "dir_exists?"  then Dir.exists?(arguments).to_s
    when "file_empty?"  then File.empty?(arguments).to_s
    when "file_exists?" then File.exists?(arguments).to_s
    when "file?"        then File.file?(arguments).to_s
    when "root_user?"   then Process.root?.to_s
      # Single arugment
    when "cd"            then Dir.cd arguments; "working directory moved"
    when "mkdir"         then FileUtils.mkdir cmd[1..-1]; "directory created"
    when "mkdir_p"       then FileUtils.mkdir_p cmd[1..-1]; "directory created"
    when "mv"            then cmd[3]? ? FileUtils.mv(cmd[1..-2], cmd[-1]) : File.rename cmd[1], cmd[2]; "file moved"
    when "rmdir"         then FileUtils.rmdir cmd[1..-1]; "directory removed"
    when "rm"            then FileUtils.rm cmd[1..-1]; "file removed"
    when "rm_r"          then FileUtils.rm_r cmd[1..-1]; "directory removed"
    when "rm_rf"         then FileUtils.rm_rf cmd[1..-1]; "directory removed"
    when "dirname"       then File.dirname arguments
    when "read"          then File.read arguments
    when "file_size"     then File.size(arguments).to_s
    when "touch"         then File.touch arguments; "file created/updated"
    when "readable?"     then File.readable?(arguments).to_s
    when "symlink?"      then File.symlink?(arguments).to_s
    when "writable?"     then File.writable?(arguments).to_s
    when "expand_path"   then File.expand_path arguments
    when "real_path"     then File.real_path arguments
    when "random_base64" then Random::Secure.urlsafe_base64(cmd[1].to_i).to_s
      # Double argument with space separator
    when "append"  then File.open cmd[1], "a", &.print cmd[2..-1].join(' ').lchop('\'').rchop('\''); "text appended"
    when "cp"      then FileUtils.cp cmd[1], cmd[2]; "file copied"
    when "cp_r"    then FileUtils.cp_r cmd[1], cmd[2]; "directory copied"
    when "link"    then File.link cmd[1], cmd[2]; "hard link created"
    when "symlink" then File.symlink cmd[1], cmd[2]; "symbolic link created"
    when "write"   then File.write cmd[1], cmd[2..-1].join(' ').lchop('\'').rchop('\''); "text written"
    when "chmod" then File.chmod cmd[1], cmd[2].to_i(8); "permissions changed"
    # Custom
    when "dir" then Dir.current
    when "ls"
      directory = cmd[1]? || Dir.current
      Dir.new(directory).children.join '\n'
    when "get" then ::Config.read(Path[cmd[1]]).get(cmd[2]).to_s
    when "del"
      config_path = Path[cmd[1]]
      config = ::Config.read config_path
      result = config.del(cmd[2]).to_s
      File.write config_path.to_s, config.build
      result
    when "set"
      config_path = Path[cmd[1]]
      config = ::Config.read config_path
      result = config.set(cmd[2], cmd[3..-1].join(' ')).to_s
      File.write config_path.to_s, config.build
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
    when "untar_bz2" then Host.exec "/bin/tar", {"jxf", cmd[1], "-C", cmd[2]}; "bzip2 archive extracted"
    when "untar_gz"  then Host.exec "/bin/tar", {"zxf", cmd[1], "-C", cmd[2]}; "gzip archive extracted"
    when "untar_lz"  then Host.exec "/bin/tar", {"axf", cmd[1], "-C", cmd[2]}; "lz archive extracted"
    when "untar_xz"  then Host.exec "/bin/tar", {"Jxf", cmd[1], "-C", cmd[2]}; "xz archive extracted"
    when "unzip"     then Host.exec "/usr/bin/unzip", {"-oq", cmd[1], "-d", cmd[2]}; "zip archive extracted"
    when "un7z"      then Host.exec "/usr/bin/7z", {"e", "-y", cmd[1], "-o" + cmd[2]}; "7z archive extracted"
    when "error"     then raise arguments.lstrip
    when "true"      then "true"
    when "false"     then "false"
    when "puts"      then arguments.lstrip
    else
      # check if the command is available in `bin` of the package and dependencies
      if bin = executable?(command) || Process.find_executable(command)
        success = false
        output, error = Exec.new bin, cmd[1..-1], error: Log.error, env: @vars do |process|
          success = true if process.wait.success?
        end
        if success
          output.to_s
        else
          raise "Execution returned an error: #{command} #{cmd.join ' '}\n#{output}\n#{error}"
        end
      else
        raise "Unknown command or variable: #{cmd.join ' '}"
      end
    end
  end
end
