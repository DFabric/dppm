module Config::CLI
  extend self

  def get(prefix, nopkg : Bool, application, path)
    file = ::Package::Path.new(prefix).app + '/' + application
    if nopkg
      config = Config.new path
      return config.data if path == "."
      config.get path
    elsif path == "."
      config = Config::Pkg.new file
      String.build do |str|
        config.pkg.as_h.each_key do |key|
          str << key << ": " << config.get(key.as_s) << '\n'
        end
      end
    else
      Config.new(file).get path
    end
  end

  def set(prefix, nopkg : Bool, application, path, value)
    file = ::Package::Path.new(prefix).app + '/' + application
    if nopkg
      Config.new(file).set path, value
    else
      Config::Pkg.new(file).set path, value
    end
  end

  def del(prefix, nopkg : Bool, application, path)
    file = ::Package::Path.new(prefix).app + '/' + application
    if nopkg
      Config.new(file).del path
    else
      Config::Pkg.new(file).del path
    end
  end
end
