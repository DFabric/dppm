module Service::OpenRC
  def parse(file)
    service = Hash(String, Hash(String, String) | Hash(String, Array(String)) | Array(String) | String).new
    supervise = Hash(String, String).new

    data = File.read file
    data.each_line do |line|
      if line =~ /^([a-z_]+)=\"(.*)\"$/
        service[$1] = $2
      elsif line =~ /^(?:[\s\t]+)?--([a-z]+) \'(.*)\'$/
        supervise[$1] = $2
      end
    end

    service["supervise_daemon_args"] = supervise

    # If there are functions like "depends"
    data.scan(/\n([a-z_]+)\(\) {\n(.*?)}/m).each do |content|
      if content[1] == "depend"
        depend = Hash(String, Array(String)).new
        content[2].lines.each do |line|
          if line =~ /^(?:[\s\t]+)?([a-z]+) (.*)/
            depend[$1] = $2.split ' '
          else
            break
          end
        end
        service["depend"] = depend
      else
        func = Array(String).new
        content[2].each_line { |line| func << line.match(/^(?:[\s\t]+)?(.*)/).not_nil![1] }
        service[content[1]] = func
      end
    end
    service
  end
end
