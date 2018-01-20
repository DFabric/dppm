module Service::Systemd
  def section(name)
    case name
    when "directory"     then ["Service", "WorkingDirectory"]
    when "command"       then ["Service", "ExecStart"]
    when "user"          then ["Service", "User"]
    when "group"         then ["Service", "Group"]
    when "after"         then ["Unit", "After"]
    when "want"          then ["Unit", "Wants"]
    when "environment"   then ["Service", "Environment"]
    when "description"   then ["Unit", "Description"]
    when "restart_delay" then ["Service", "RestartSec"]
    when "network"       then ["network.target"]
    when "umask"         then ["Service", "UMask"]
    when "reload"        then ["Service", "ExecReload"]
    else
      raise "don't exist in systemd: " + name
    end
  end

  def get(data, name)
    key = section name
    data[keys[0]][keys[1]]
  end

  def set(data, name, value)
    keys = section name
    data[keys[0]][keys[1]] = if name == "reload"
                               "/bin/kill -#{value} $MAINPID"
                             else
                               value
                             end
    data
  end

  def env_get(data, env)
    Service::Env.get data["Service"]["Environment"], env
  end

  def env_set(data, env, value)
    data["Service"]["Environment"] = Service::Env.set data["Service"]["Environment"]?.to_s, env, value
    data
  end
end
