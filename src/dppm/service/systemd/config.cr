class Service::Systemd::Config
  getter section = Hash(String, Hash(String, String)).new

  def initialize
    @section = base
  end

  def initialize(data : String, file = false)
    if file && File.exists? data
      parse File.read data
    elsif file
      @section = base
    else
      parse data
    end
  end

  def base
    {"Unit" => {
      "After" => "network.target",
    },
     "Service" => {
       "Type"    => "simple",
       "Restart" => "always",
     },
     "Install" => {
       "WantedBy" => "multi-user.target",
     }}
  end

  def shim(name)
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
    when "pidfile"       then ["Service", "PIDFile"]
    when "log_error"     then ["Service", "StandardOutput"]
    when "log_output"    then ["Service", "StandardError"]
    else
      raise "don't exist in systemd: " + name
    end
  end

  def get(name)
    keys = shim name
    @section[keys[0]][keys[1]]
  end

  def set(name, value)
    keys = shim name
    @section[keys[0]][keys[1]] = if name == "reload"
                                   "/bin/kill -#{value} $MAINPID"
                                 else
                                   value
                                 end
  end

  def env_get(env)
    Service::Env.new(@section["Service"]["Environment"]).get env
  end

  def env_set(env, value)
    @section["Service"]["Environment"] = Service::Env.new(@section["Service"]["Environment"]?).set env, value
  end
end
