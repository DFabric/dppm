struct Service::OpenRC::Config
  getter section : Hash(String, String | Array(String))
  getter depend : Hash(String, Array(String))

  def initialize(@section : Hash(String, String | Array(String)), @depend : Hash(String, Array(String)))
  end

  def self.new(file : String? = nil) : Config
    if file && File.exists? file
      parse File.read(file)
    else
      new base_section, base_depend
    end
  end

  def self.base_section
    {"pidfile"    => "/run/${RC_SVCNAME}.pid",
     "supervisor" => "supervise-daemon",
     "reload"     => ["eerror \"Reloading not available for $RC_SVCNAME\""]}
  end

  def self.base_depend
    {
      "after" => ["net"],
    }
  end

  def compat_layer(name : String)
    case name
    when "directory"     then {"chdir"}
    when "user"          then {"user"}
    when "group"         then {"group"}
    when "after"         then {"depend", "after"}
    when "before"        then {"depend", "before"}
    when "want"          then {"depend", "want"}
    when "environment"   then {"env"}
    when "description"   then {"description"}
    when "restart_delay" then {"respawn_delay"}
    when "network"       then {"net"}
    when "umask"         then {"umask"}
    when "reload"        then {"reload"}
    when "pidfile"       then {"pidfile"}
    when "log_output"    then {"stdout"}
    when "log_error"     then {"stderr"}
    else                      raise "don't exist in openrc: " + name
    end
  end

  def get(name : String)
    if name == "command"
      return "#{@section["command"]} #{@section["command_args"]}"
    end
    case keys = compat_layer name
    when Tuple(String)         then @section[keys[0]]
    when Tuple(String, String) then @section[keys[1]]
    else
      raise "invalid keys: #{keys}"
    end
  end

  def set(name : String, value)
    case name
    when "command"
      @section["command"], @section["command_args"] = value.split ' ', limit: 2
    when "reload"
      @section["extra_started_commands"] = ["reload"]
      @section["reload"] = ["ebegin \"Reloading $RC_SVCNAME\"",
                            "supervise-daemon --signal #{value} --pidfile \"$pidfile\"",
                            "eend $? \"Failed to reload $RC_SVCNAME\""]
    else
      case keys = compat_layer name
      when Tuple(String)
        @section[keys[0]] = value
      when Tuple(String, String)
        @depend[keys[1]] = value.split(' ')
      else
        raise "only size of 0 and 1 is available: #{keys}"
      end
    end
  end

  def env_get(env)
    Service::Env.new(@section["env"]?).get env
  end

  def env_set(env, value)
    @section["env"] = Service::Env.new(@section["env"]?).set env, value
  end
end
