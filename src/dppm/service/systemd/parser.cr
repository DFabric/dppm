module Service::Systemd
  def space_array
    {"Unit"    => ["Requires", "Wants", "After", "Before", "Environment"],
     "Service" => [""],
     "Install" => ["WantedBy", "RequiredBy"]}
  end

  def parse(file)
    systemd = Hash(String, Hash(String, String | Array(String))).new
    section = ""
    File.read(file).each_line do |line|
      if line =~ /([A-Z][A-Za-z]+)=(.*)/
        if space_array[section].includes? $1
          systemd[section][$1] = $2.split ' '
        else
          systemd[section][$1] = $2
        end
      elsif line =~ /\[(.*)\]/
        section = $1
        systemd[section] = Hash(String, String | Array(String)).new
        # Not empty and not commented line
      elsif !line.empty? && !line =~ /(?:[\s]+)?;.*/
        raise "systemd failed to parse: " + line
      end
    end
    systemd
  end
end
