require "colorize"

module DPPM::Log
  extend self
  class_property output : IO::FileDescriptor = STDOUT
  class_property error : IO::FileDescriptor = STDERR
  class_property colorize : Bool = output.tty?
  class_property date : Bool = false

  def print_date(io)
    Time.utc_now.to_s("%F %T%z ", io) if @@date
  end

  def info(title : String, message : String)
    print_date @@output
    if @@colorize
      @@output << "INFO".colorize.blue.mode(:bold) << ' ' << title.colorize.white << ": " << message << '\n'
    else
      @@output << "INFO \"" << title << ": " << message << "\"\n"
    end
    @@output.flush
  end

  def warn(title : String, message : String)
    print_date @@error
    if @@colorize
      @@error << "WARN".colorize.yellow.mode(:bold) << ' ' << title.colorize.white.mode(:bold) << ": " << message << '\n'
    else
      @@error << "WARN \"" << title << ": " << "message\"\n"
    end
    @@error.flush
  end

  def error(message : String)
    print_error message
  end

  private def print_error(message)
    print_date @@error
    if @@colorize
      @@error << "ERR!".colorize.red.mode(:bold) << ' ' << message.colorize.light_magenta << '\n'
    else
      @@error << "ERR! \"" << message << "\"\n"
    end
    @@error.flush
  end

  def error(ex : Exception)
    print_error ex
    if cause = ex.cause
      error cause
    end
  end

  def finalize
    @@output.close
    @@error.close
  end
end
