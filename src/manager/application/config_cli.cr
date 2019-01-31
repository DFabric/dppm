module Manager::Application::ConfigCLI
  extend self

  def get(prefix, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      return app.config!.data if nopkg && path == "."
      app.config!.get path
    elsif path == "."
      String.build do |str|
        app.pkg_file.config.each_key do |key|
          str << key << ": " << app.get_config(key) << '\n'
        end
      end
    else
      app.get_config path
    end
  end

  def set(prefix, nopkg : Bool, application, path, value, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      app.config!.set path, value
    else
      app.set_config path, value
    end
  end

  def del(prefix, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      app.config!.del path
    else
      app.del_config path
    end
  end
end
