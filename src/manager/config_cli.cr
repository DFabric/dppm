module Manager::ConfigCLI
  extend self

  def get(prefix, nopkg : Bool, application, path, **args)
    config = config prefix, nopkg, application
    if config.is_a? Config
      return config.data if nopkg && path == "."
      config.get path
    elsif config.is_a?(Config::Pkg) && path == "."
      String.build do |str|
        config.pkg_config.each_key do |key|
          str << key << ": " << config.get(key) << '\n'
        end
      end
    end
  end

  def set(prefix, nopkg : Bool, application, path, value, **args)
    config(prefix, nopkg, application).set path, value
  end

  def del(prefix, nopkg : Bool, application, path, **args)
    config(prefix, nopkg, application).del path
  end

  private def config(prefix, nopkg, application)
    path = Path.new(prefix).app + application
    if nopkg
      Config.new path
    else
      pkg_file = PkgFile.new path
      if pkg_file_config = pkg_file.config
        Config::Pkg.new path, pkg_file_config
      else
        raise "no `config` key in " + pkg_file.path
      end
    end
  end
end
