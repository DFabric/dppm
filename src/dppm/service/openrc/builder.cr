module Service::OpenRC
  def build(data)
    # File.write(file,
    String.build do |str|
      str << "#!/sbin/openrc-run\n\n"

      # Variables firt
      str << data.map do |k, v|
        k + "=\"#{v}\"\n" if v.is_a? String
      end.join
      str << data.map do |content, section|
        # supervise_daemon_args
        if section.is_a? Hash(String, String)
          "\n#{content}=\"\n" + section.map do |k, v|
            "\t--#{k} \'#{v}\'\n"
          end.join + "\"\n"
        elsif section.is_a? Array(String)
          '\n' + content + "() {\n\t" + section.join("\n\t") + "\n}\n"
          # depend
        elsif section.is_a? Hash(String, Array(String))
          "\n#{content}() {\n" + section.map do |k, a|
            '\t' + k + ' ' + a.join(' ') + '\n'
          end.join + "}\n"
        end
      end.join << '\n'
    end
  end
end
