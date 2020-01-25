require "ini"
require "./config"

class Service::Systemd::Config < Service::Config
  # class Service::Config
  private SYSTEMD_SHELL_LOG_REDIRECT = "/bin/sh -c '2>>"
  private SYSTEMD_NETWORK_SERVICE    = "network.target"

  @extra_service_options : Hash(String, String) = Hash(String, String).new

  def initialize
  end

  def initialize(data : String | IO)
    ini = INI.parse data
    if reload = ini["Service"].delete "ExecReload"
      @reload_signal = reload.lchop("/bin/kill -").rchop(" $MAINPID")
    end
    if restart_delay = ini["Service"].delete "RestartSec"
      @restart_delay = restart_delay.to_u32
    end
    if after = ini["Unit"]["After"]?
      after.split ' ' do |service_name|
        if service_name != SYSTEMD_NETWORK_SERVICE
          @after << service_name.rchop ".service"
        end
      end
    end
    if env_vars = ini["Service"].delete "Environment"
      parse_env_vars env_vars
    end

    if log_output = ini["Service"].delete "StandardOutput"
      @log_output = log_output.lstrip "file:"
    end
    if log_error = ini["Service"].delete "StandardError"
      @log_error = log_error.lstrip "file:"
    end

    if command = ini["Service"].delete "ExecStart"
      if shell_command = command.lchop? SYSTEMD_SHELL_LOG_REDIRECT
        @log_error, _, output_with_command = shell_command.partition " >>"
        @log_output, _, @command = output_with_command.rchop.partition ' '
      else
        @command = command
      end
    end

    @description = ini["Unit"]["Description"]?
    @user = ini["Service"].delete "User"
    @group = ini["Service"].delete "Group"
    @directory = ini["Service"].delete "WorkingDirectory"
    @umask = ini["Service"].delete "UMask"
    @extra_service_options = ini["Service"]
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def build(io : IO) : Nil
    # Transform the hash to a systemd service
    systemd = {"Unit"    => Hash(String, String).new,
               "Service" => {
                 "Type"    => "simple",
                 "Restart" => "always",
               },
               "Install" => {
                 "WantedBy" => "multi-user.target",
               }}
    systemd["Service"].merge! @extra_service_options
    systemd["Service"]["ExecReload"] = "/bin/kill -#{@reload_signal} $MAINPID" if @reload_signal
    if user = @user
      systemd["Service"]["User"] = user
    end
    if group = @group
      systemd["Service"]["Group"] = group
    end

    # File logging introduced in systemd 236
    # A hack using shell redirection is needed before
    if Systemd.version < 236
      if (command = @command) && (log_output = @log_output) && (log_error = @log_error)
        systemd["Service"]["ExecStart"] = SYSTEMD_SHELL_LOG_REDIRECT + log_error + " >>" + log_output + ' ' + command + '\''
      end
    else
      if command = @command
        systemd["Service"]["ExecStart"] = command
      end
      if log_output = @log_output
        systemd["Service"]["StandardOutput"] = "file:" + log_output
      end
      if log_error = @log_error
        systemd["Service"]["StandardError"] = "file:" + log_error
      end
    end

    if directory = @directory
      systemd["Service"]["WorkingDirectory"] = directory
    end
    if description = @description
      systemd["Unit"]["Description"] = description
    end
    if umask = @umask
      systemd["Service"]["UMask"] = umask
    end
    if restart_delay = @restart_delay
      systemd["Service"]["RestartSec"] = restart_delay.to_s
    end

    @after << SYSTEMD_NETWORK_SERVICE
    systemd["Unit"]["After"] = String.build do |str|
      @after.join(' ', str) do |service|
        str << service
        str << ".service" if service != SYSTEMD_NETWORK_SERVICE
      end
    end

    if !@env_vars.empty?
      systemd["Service"]["Environment"] = build_env_vars
    end
    INI.build io, systemd
  end
end
