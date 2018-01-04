module Service::OpenRC
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
end
