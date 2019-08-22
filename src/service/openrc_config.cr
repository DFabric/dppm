require "./config"

class Service::Config
  private OPENRC_RELOAD_COMMAND  = "supervise-daemon --pidfile \"$pidfile\" --signal "
  private OPENRC_PIDFILE         = "pidfile=\"/run/${RC_SVCNAME}.pid\""
  private OPENRC_SHEBANG         = "#!/sbin/openrc-run"
  private OPENRC_SUPERVISOR      = "supervisor=supervise-daemon"
  private OPENRC_ENV_VARS_PREFIX = "supervise_daemon_args=\"--env '"
  private OPENRC_NETWORK_SERVICE = "net"

  def self.from_openrc(data : String)
    service = new
    line_number = 1
    function_name = ""

    data.each_line do |full_line|
      line = full_line.lstrip "\n\t "
      if line.ends_with? '}'
        function_name = ""
      elsif function_name = line.rchop? "() {"
      elsif service.description = line.lchop?("description='").try &.rchop
      elsif service.directory = line.lchop?("directory='").try &.rchop
      elsif service.umask = line.lchop? "umask="
      elsif service.log_output = line.lchop?("output_log='").try &.rchop
      elsif service.log_error = line.lchop?("error_log='").try &.rchop
      elsif service.restart_delay = line.lchop?("respawn_delay=").try &.to_u32
      elsif service.command = line.lchop?("command='").try &.rchop.+ service.command.to_s
      elsif command_args = line.lchop?("command_args='")
        service.command = service.command.to_s + ' ' + command_args.rchop
      elsif command_user = line.lchop?("command_user='")
        user_and_group = command_user.rchop.partition ':'
        service.user = user_and_group[0].empty? ? nil : user_and_group[0]
        service.group = user_and_group[2].empty? ? nil : user_and_group[2]
      elsif openrc_env_vars = line.lchop?(OPENRC_ENV_VARS_PREFIX)
        service.parse_env_vars openrc_env_vars.rchop("'\"")
      else
        case line
        when .empty?,
             OPENRC_SHEBANG,
             OPENRC_SUPERVISOR,
             OPENRC_PIDFILE,
             "\"",
             .starts_with?("extra_started_commands"),
             .starts_with?("pidfile")
          next
        end
        case function_name
        when "depend"
          directive = true
          line.split(' ') do |element|
            if directive
              raise "Unsupported line depend directive: " + element if element != "after"
              directive = false
            elsif element != OPENRC_NETWORK_SERVICE
              service.after << element
            end
          end
        when "reload"
          if reload_signal = line.lchop? OPENRC_RELOAD_COMMAND
            service.reload_signal = reload_signal
          end
        else
          raise "Unsupported line"
        end
      end
      line_number += 1
    rescue ex
      raise Exception.new "Parse error line at #{line_number}: #{full_line}", ex
    end
    service
  end

  def to_openrc : String
    String.build do |str|
      str << OPENRC_SHEBANG << "\n\n"
      str << OPENRC_SUPERVISOR << '\n'
      str << OPENRC_PIDFILE
      str << "\nextra_started_commands=reload" if @reload_signal
      str << "\ncommand_user='#{@user}:#{@group}'" if @user || @group
      str << "\ndirectory='" << @directory << '\'' if @directory
      if command = @command
        command_elements = command.partition ' '
        str << "\ncommand='" << command_elements[0] << '\''
        if !command_elements[2].empty?
          str << "\ncommand_args='" << command_elements[2] << '\''
        end
      end
      str << "\noutput_log='" << @log_output << '\'' if @log_output
      str << "\nerror_log='" << @log_error << '\'' if @log_error
      str << "\ndescription='" << @description << '\'' if @description
      str << "\nrespawn_delay=" << @restart_delay if @restart_delay
      str << "\numask=" << @umask if @umask

      if !@env_vars.empty?
        str << '\n' << OPENRC_ENV_VARS_PREFIX
        build_env_vars str
        str << "'\""
      end

      str << "\n\ndepend() {\n\tafter "
      @after << OPENRC_NETWORK_SERVICE
      @after.join ' ', str
      str << "}\n"

      if @reload_signal
        str << <<-E

        reload() {
        \tebegin "Reloading $RC_SVCNAME"
        \t#{OPENRC_RELOAD_COMMAND}#{@reload_signal}
        \teend $? "Failed to reload $RC_SVCNAME"
        }
        
        E
      end
    end
  end
end
