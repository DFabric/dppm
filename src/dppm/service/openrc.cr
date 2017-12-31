struct Service::OpenRC
  include Service
  getter base = {
    "pidfile"               => "/run/${RC_SVCNAME}.pid",
    "supervisor"            => "supervise-daemon",
    "supervise_daemon_args" => {
      "stdout" => "/var/log/${RC_SVCNAME}_out.log",
      "stderr" => "/var/log/${RC_SVCNAME}_err.log",
    },
    "depend" => {
      "after" => ["net"],
    },
    "reload" => ["eerror \"Reloading not available for $RC_SVCNAME\""],
  }

  # !/sbin/openrc-run

  # description="PHP FastCGI Process Manager"
  #
  # start_stop_daemon_vars="--quiet"
  # pidfile="/run/$RC_SVCNAME/php-fpm.pid"
  #
  # supervisor="supervise-daemon"
  #
  # depend() {
  #   after net
  #   use apache2 lighttpd nginx
  # }
  #
  # reload() {
  # 	ebegin "Reloading $name"
  # 	start-stop-daemon --signal USR2 --pidfile "$pidfile"
  # 	eend $?
  # }
  #
  # reopen() {
  # 	ebegin "Reopening $name log files"
  # 	start-stop-daemon --signal USR1 --pidfile "$pidfile"
  #   eend $?
  # }

  def name
    "OpenRC"
  end

  private def shim(name)
    case name
    when "directory"     then ["supervise_daemon_args", "chdir"]
    when "user"          then ["supervise_daemon_args", "user"]
    when "group"         then ["supervise_daemon_args", "group"]
    when "after"         then ["depend", "after"]
    when "want"          then ["depend", "want"]
    when "environment"   then ["supervise_daemon_args", "env"]
    when "description"   then ["description"]
    when "restart_delay" then ["respawn_delay"]
    when "network"       then ["net"]
    when "umask"         then ["supervise_daemon_args", "umask"]
    when "reload"        then ["reload"]
    else
      raise "don't exist in openrc: " + name
    end
  end

  def get(data, name)
    if name == "command"
      return "#{data["command"]} #{data["command_args"]}"
    end
    keys = shim name
    case keys.size
    when 1 then data[keys[0]]
    when 2 then data[keys[0]].to_s[keys[1]]
    else
      raise "openrc: only size of 1 and 2 is available: #{keys}"
    end
  end

  def set(data, name, value)
    if name == "command"
      command = value.split ' '
      data["command"] = command[0]
      data["command_args"] = command[1..-1].join ' '
      return data
    elsif name == "reload"
      data["extra_started_commands"] = "reload"
      data["reload"] = ["ebegin \"Reloading $RC_SVCNAME\"",
                        "supervise-daemon \\",
                        "\t--exec \"#{data["command"]}\" \\",
                        "\t--signal \"#{value}\" \\",
                        "\t--user \"#{get data, "user"}\" \\",
                        "\t--group \"#{get data, "group"}\" \\",
                        "\t--pidfile \"$pidfile\"",
                        "eend $? \"Failed to reload $RC_SVCNAME\""]
      return data
    end
    keys = shim name
    if keys.size == 1
      data[keys[0]] = value
    elsif keys.size == 2
      subdata = data[keys[0]]
      if subdata.is_a? Hash(String, String)
        subdata[keys[1]] = value
      elsif subdata.is_a? Hash(String, Array(String))
        subdata[keys[1]] << value
      else
        raise "unknown type: " + subdata.to_s
      end
    else
      raise "only size of 0 and 1 is available: #{keys}"
    end
    data
  end

  def get(data, keys : Array(String))
    if keys[0] = "environment"
      get_env data["supervise_daemon_args"]["env"], keys[1]
    else
      raise "not supported by openrc #{keys}"
    end
  end

  def set(data, keys : Array(String), value)
    if keys[0] = "environment"
      env_vars = data["supervise_daemon_args"]
      if env_vars.is_a? Hash(String, String)
        env_vars["env"] = set_env env_vars["env"]?.to_s, keys[1], value
      else
        raise "environment variables aren't as a String: #{env_vars}"
      end
      data["supervise_daemon_args"] = env_vars
    else
      raise "not supported by systemd #{keys}"
    end
    data
  end

  def writable?
    File.writable? "/etc/init.d/"
  end

  def file(service)
    "/etc/init.d/" + service
  end

  def link(pkgdir, service)
    File.symlink pkgdir + "/etc/init/systemd", file(service)
    File.chmod file(service), 0o755
  end

  def boot(service)
    File.exists?("/etc/runlevels/default/" + service)
  end

  def boot(service, value : Bool)
    boot = "/etc/runlevels/default/" + service
    value ? File.symlink(file(service), boot) : File.delete(boot)
  end

  def run(service)
    Exec.new("/sbin/rc-service", [service, "status"]).success?
  end

  def run(service, value : Bool) : Bool
    boot = "/etc/runlevels/default/" + service
    Exec.new("/sbin/rc-service", [service, (value ? "start" : "stop")]).success?
  end

  def reload(service)
    Exec.new("/sbin/rc-service", [service, "reload"]).success?
  end

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

  def build(data)
    # File.write(file,
    String.build do |str|
      str << "#!/sbin/openrc-run\n\n"

      # Variables firt
      str << data.map do |k, v|
        k + "=\"#{v}\"\n" if v.is_a? String
      end.join
      str << data.map do |content, section|
        # supervise_daemon_args
        if section.is_a? Hash(String, String)
          "\n#{content}=\"\n" + section.map do |k, v|
            "\t--#{k} \'#{v}\'\n"
          end.join + "\"\n"
        elsif section.is_a? Array(String)
          '\n' + content + "() {\n\t" + section.join("\n\t") + "\n}\n"
          # depend
        elsif section.is_a? Hash(String, Array(String))
          "\n#{content}() {\n" + section.map do |k, a|
            '\t' + k + ' ' + a.join(' ') + '\n'
          end.join + "}\n"
        end
      end.join
    end
  end

  def log
    # "/var/log/" + service + ".log"
  end
end
