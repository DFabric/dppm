struct Service::OpenRC::Config
  def build : String
    supervise = "\nsupervise_daemon_args=\"\n"
    functions = depend = extra = ""

    String.build do |str|
      str << "#!/sbin/openrc-run\n\n"

      @section.each do |key, section|
        # supervise_daemon_args
        case section
        when String
          case key
          when "command", "command_args", "supervisor", "pidfile", "respawn_delay", "description"
            str << key << "=\'#{section}\'\n"
          else
            supervise += "\t--#{key} \'#{section}\'\n"
          end
          # function
        when Array(String)
          if EXTRAS.includes? key
            extra += "#{key}=\'#{section.join ' '}\'\n"
          else
            functions += "#{key}() {\n\t#{section.join("\n\t")}\n}"
          end
        end
      end
      str << supervise << "\"\n\n"
      str << extra << '\n' if !extra.empty?
      if !@depend.empty?
        str << "depend() {\n"
        @depend.each do |key, services|
          str << '\t' << key
          services.join ' ', str
          str << '\n'
        end
        str << "}\n\n"
      end
      str << functions << "\n\n" if !functions.empty?
    end
  end
end
