module Config::CLI
  extend self

  def get(prefix, nopkg : Bool, application, path)
    file = Path.new(prefix).app + application
    if nopkg
      config = Config.new path
      return config.data if path == "."
      config.get path
    elsif path == "."
      config = Pkg.new file
      String.build do |str|
        config.pkg.as_h.each_key do |key|
          str << key << ": " << config.get(key.as_s) << '\n'
        end
      end
    else
      Config.new(file).get path
    end
  end

  private def config(prefix, nopkg, application)
    file = Path.new(prefix).app + application
    nopkg ? Config.new(file) : Pkg.new file
  end

  def set(prefix, nopkg : Bool, application, path, value)
    config(prefix, nopkg, application).set path, value
  end

  def del(prefix, nopkg : Bool, application, path)
    config(prefix, nopkg, application).del path
  end
end
