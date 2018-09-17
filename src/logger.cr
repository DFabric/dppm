require "colorize"

struct Log
  class_setter colorize = true
  class_setter date = false
  class_setter destination : IO::FileDescriptor = STDOUT

  def self.date
    @@destination << Time.now.to_s("%F %T%z ") if @@date
  end

  def self.info(title : String, message : String)
    date
    @@destination.puts(if colorize
      "#{"INFO".colorize.blue.mode(:bold)} #{title.colorize.white}: #{message}"
    else
      "INFO \"#{title}: #{message}\""
    end)
  end

  def self.warn(title : String, message : String)
    date
    @@destination.puts(if colorize
      "#{"WARN".colorize.yellow.mode(:bold)} #{title.colorize.white.mode(:bold)}: #{message}"
    else
      "WARN \"#{title}: #{message}\""
    end)
  end

  def self.error(message : String)
    date
    @@destination.puts(if colorize
      "#{"ERR!".colorize.red.mode(:bold)} #{message.colorize.light_magenta}"
    else
      "ERR! \"#{message}\""
    end)
    exit 1
  end
end
