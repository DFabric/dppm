require "tail"

module Logs
  def self.get(prefix, lines, error, follow, application, &block : String -> _)
    log_file = Path.new(prefix).application_log application, error
    tail = Tail::File.new log_file
    if follow
      tail.follow(lines: (lines ? lines.to_i : 10), &block)
    elsif lines
      yield tail.last_lines(lines: lines.to_i).join '\n'
    else
      yield File.read log_file
    end
  end
end
