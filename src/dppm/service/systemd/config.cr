module Service::Systemd
  private def shim(name)
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
    keys = shim name
    data[keys[0]][keys[1]]
  end

  def set(data, name, value)
    keys = shim name
    data[keys[0]][keys[1]] = if name == "reload"
                               "/bin/kill -#{value} $MAINPID"
                             else
                               value
                             end
    data
  end

  def get(data, keys : Array(String))
    if keys[0] = "environment"
      get_env data["Service"]["Environment"], keys[1]
    else
      raise "not supported by systemd #{keys}"
    end
  end

  def set(data, keys : Array(String), value)
    if keys[0] = "environment"
      data["Service"]["Environment"] = set_env data["Service"]["Environment"]?.to_s, keys[1], value
    else
      raise "not supported by systemd #{keys}"
    end
    data
  end
end
