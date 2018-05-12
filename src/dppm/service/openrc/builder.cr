class Service::OpenRC::Config
  def build
    # File.write(file,
    supervise = "\nsupervise_daemon_args=\"\n"
    functions = depend = extra = ""

    String.build do |str|
      str << "#!/sbin/openrc-run\n\n"

      @section.each do |key, section|
        # supervise_daemon_args
        if section.is_a? String
          case key
          when "command", "command_args", "supervisor", "pidfile", "respawn_delay", "description"
            str << key << "=\'#{section}\'\n"
          else
            supervise += "\t--#{key} \'#{section}\'\n"
          end
          # function
        elsif section.is_a? Array(String)
          if @extras.includes? key
            extra += "#{key}=\'#{section.join ' '}\'\n"
          else
            functions += "#{key}() {\n\t#{section.join("\n\t")}\n}"
          end
          # depend
        elsif section.is_a? Hash(String, Array(String))
          depend += "depend() {\n" + section.map { |k, a| "\t#{k} #{a.join ' '}\n" }.join + '}'
        end
      end
      str << supervise << "\"\n\n"
      str << extra << '\n' if !extra.empty?
      str << depend << "\n\n" if !depend.empty?
      str << functions << "\n\n" if !functions.empty?
    end
  end
end
