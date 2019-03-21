require "colorize"

module Log
  extend self
  class_property output : IO::FileDescriptor = STDOUT
  class_property error : IO::FileDescriptor = STDERR
  @@colorize = true
  @@date = false

  def print_date(io)
    Time.now.to_s("%F %T%z ", io) if @@date
  end

  def info(title : String, message : String)
    print_date @@output
    if colorize
      @@output << "INFO".colorize.blue.mode(:bold) << ' ' << title.colorize.white << ": " << message << '\n'
    else
      @@output << "INFO \"" << title << ": " << message << "\"\n"
    end
  end

  def warn(title : String, message : String)
    print_date @@error
    if colorize
      @@error << "WARN".colorize.yellow.mode(:bold) << ' ' << title.colorize.white.mode(:bold) << ": " << message << '\n'
    else
      @@error << "WARN \"" << title << ": " << "message\"\n"
    end
  end

  def error(message : String)
    print_date @@error
    if colorize
      @@error << "ERR!".colorize.red.mode(:bold) << ' ' << message.colorize.light_magenta << '\n'
    else
      @@error << "ERR! \"" << message << "\"\n"
    end
  end

  def finalize
    output.close
    error.close
  end
end
