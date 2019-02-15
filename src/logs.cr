require "tail"
require "./prefix"

module Logs
  def self.get(prefix : String, lines : String?, error : Bool, follow : Bool, application : String, **args, &block : String ->)
    log_file = Prefix.new(prefix).new_app(application).log_file error
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
