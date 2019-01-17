struct Service::OpenRC::Config
  EXTRAS = {"extra_command", "extra_started_commands", "extra_stopped_commands"}

  def self.parse(data : String)
    section = Hash(String, String | Array(String) | Hash(String, Array(String))).new
    line_number = 1
    function_name = ""
    function = Array(String).new
    depend = Hash(String, Array(String)).new

    data.each_line do |full_line|
      line = full_line.lstrip "\t "
      if line.starts_with? "--"
        key, val = line.split '\''
        section[key[2..-2]] = val
      elsif line.ends_with? '\''
        key, val = line.split '='
        section[key] = if EXTRAS.includes? key
                         val[1..-2].split ' '
                       else
                         val[1..-2]
                       end
      elsif line.ends_with? '}'
        section[function_name] = function
        function_name = ""
        function = Array(String).new
      elsif function_name == "depend"
        values = line.split ' '
        depend[values[0]] = values[1..-1]
      elsif !function_name.empty?
        function << line
      elsif line.ends_with? '{'
        function_name = line.split('(')[0]
      end
      line_number += 1
    rescue
      raise "parse error line #{line_number}: #{full_line}"
    end
    section["depend"] = depend
    new section
  end
end
