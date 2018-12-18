require "colorize"

struct Log
  class_property output : IO::FileDescriptor = STDOUT
  class_property error : IO::FileDescriptor = STDERR
  @@colorize = true
  @@date = false

  def self.date
    @@output << Time.now.to_s("%F %T%z ") if @@date
  end

  def self.info(title : String, message : String)
    date
    @@output.puts(if colorize
      "#{"INFO".colorize.blue.mode(:bold)} #{title.colorize.white}: #{message}"
    else
      "INFO \"#{title}: #{message}\""
    end)
  end

  def self.warn(title : String, message : String)
    date
    @@error.puts(if colorize
      "#{"WARN".colorize.yellow.mode(:bold)} #{title.colorize.white.mode(:bold)}: #{message}"
    else
      "WARN \"#{title}: #{message}\""
    end)
  end

  def self.error(message : String)
    date
    @@error.puts(if colorize
      "#{"ERR!".colorize.red.mode(:bold)} #{message.colorize.light_magenta}"
    else
      "ERR! \"#{message}\""
    end)
    exit 1
  end
end
