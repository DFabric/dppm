struct Log
  class_setter destination : IO::FileDescriptor | String = STDOUT

  def self.info(title : String, message : String)
    case (destination = @@destination)
    when .is_a? IO::FileDescriptor then puts "#{"INFO".colorize.blue.mode(:bold)} #{title.colorize.white}: #{message}"
    when .is_a? String             then File.open destination, "a", &.print(Time.now.to_s("%F %T%z") + " INFO \"#{title}: #{message}\"\n")
    else
      raise "unknown log destination: #{@@destination}"
    end
  end

  def self.warn(title : String, message : String)
    case (destination = @@destination)
    when .is_a? IO::FileDescriptor then puts "#{"WARN".colorize.yellow.mode(:bold)} #{title.colorize.white.mode(:bold)}: #{message}"
    when .is_a? String             then File.open destination, "a", &.print(Time.now.to_s("%F %T%z") + " WARN \"#{title}: #{message}\"\n")
    else
      raise "unknown log destination: #{@@destination}"
    end
  end

  def self.error(message : String)
    case (destination = @@destination)
    when .is_a? IO::FileDescriptor then puts "#{"ERR!".colorize.red.mode(:bold)} #{message.colorize.light_magenta}"
    when .is_a? String             then File.open destination, "a", &.print(Time.now.to_s("%F %T%z") + " ERR! \"#{message}\"\n")
    else
      raise "unknown log destination: #{@@destination}"
    end
    exit 1
  end
end
