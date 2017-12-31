struct Service::Systemd
  include Service
  @space_array = {
    "Unit"    => ["Requires", "Wants", "After", "Before", "Environment"],
    "Service" => [""],
    "Install" => ["WantedBy", "RequiredBy"],
  }

  getter base = {
    "Unit" => {
      "After" => "network.target",
    },
    "Service" => {
      "Type"    => "simple",
      "Restart" => "always",
    },
    "Install" => {
      "WantedBy" => "multi-user.target",
    },
  }

  # [Unit]
  # Description=The PHP FastCGI Process Manager
  # After=network.target
  #
  # [Service]
  # Type=notify
  # PIDFile=run/php-fpm.pid
  # ExecStart=lib/php/php-fpm --nodaemonize --fpm-config /php-fpm.conf
  # ExecReload=/bin/kill -USR2 $MAINPID
  # PrivateTmp=true
  #
  # [Install]
  # WantedBy=multi-user.target

  def name
    "systemd"
  end

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

  def writable?
    File.writable? "/etc/systemd/system/"
  end

  def file(service)
    "/etc/systemd/system/" + service + ".service"
  end

  def link(pkgdir, service)
    File.symlink pkgdir + "/etc/init/systemd", file(service)
    Exec.new "/bin/systemctl", ["--no-ask-password", "daemon-reload"]
  end

  def boot(service)
    File.exists?("/etc/systemd/system/multi-user.target.wants/" + service + ".service")
  end

  def boot(service, value : Bool)
    boot = "/etc/systemd/system/multi-user.target.wants/" + service + ".service"
    value ? File.symlink(file(service), boot) : File.delete(boot)
  end

  def run(service)
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "is-active", service]).success?
  end

  def run(service, value : Bool) : Bool
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", (value ? "start" : "stop"), service]).success?
  end

  def reload(service)
    Exec.new("/bin/systemctl", ["-q", "--no-ask-password", "reload", service]).success?
  end

  def parse(file)
    systemd = Hash(String, Hash(String, String | Array(String))).new
    section = ""
    File.read(file).each_line do |line|
      if line =~ /([A-Z][A-Za-z]+)=(.*)/
        if @space_array[section].includes? $1
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

  def build(data)
    # Transform the hash to a systemd service
    systemd = Hash(String, Hash(String, String)).new
    data.each do |section, keys|
      data[section].each do |k, v|
        systemd[section] = Hash(String, String).new if !systemd[section]?
        # systemd[section][k] = v
        systemd[section][k] = v.is_a?(Array) ? v.join(' ') : v
      end
    end
    INI.build systemd
  end

  def log
    # "journalctl --no-pager -oshort -u " + service
  end
end
