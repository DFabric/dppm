module CLI::App
  extend self

  def query(prefix, application, path, **args) : String
    pkg_file = Prefix.new(prefix).new_app(application).pkg_file
    CLI.query(pkg_file.any, path).to_pretty_con
  end

  def delete(no_confirm, prefix, application, keep_user_group, preserve_database, **args)
    Prefix.new(prefix).new_app(application).delete !no_confirm, keep_user_group, preserve_database do
      CLI.confirm_prompt
    end
  end

  def add(no_confirm, config, mirror, source, prefix, application, custom_vars, contained, noservice, socket, database = nil, url = nil, web_server = nil, debug = nil)
    vars = Hash(String, String).new
    Log.info "initializing", "add"
    DPPM::Config.file = config
    vars["mirror"] = mirror || DPPM::Config.mirror
    vars_parser custom_vars, vars

    # Update cache
    root_prefix = Prefix.new prefix, true
    root_prefix.update(source || DPPM::Config.source)

    # Create task
    pkg = Prefix::Pkg.create root_prefix, application, vars["version"]?, vars["tag"]?
    app = pkg.new_app(vars["name"]?)
    app.add(
      vars: vars,
      shared: !contained,
      add_service: !noservice,
      socket: socket,
      database: database,
      url: url,
      web_server: web_server,
      confirmation: !no_confirm
    ) do
      no_confirm || CLI.confirm_prompt
    end
    app
  end

  def vars_parser(custom_vars : Array(String), vars : Hash(String, String))
    custom_vars.each do |arg|
      case arg
      when .includes? '='
        key, value = arg.split '=', 2
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !Utils.ascii_alphanumeric_underscore? key
        vars[key] = value
      else
        raise "invalid variable: #{arg}"
      end
    end
  end

  def version(prefix, application, **args) : String
    Prefix.new(prefix).new_app(application).pkg.version
  end

  def exec(prefix, application, **args)
    app = Prefix.new(prefix).new_app application

    env_vars = app.pkg_file.env || Hash(String, String).new
    env_vars["PATH"] = app.path_env_var

    exec_start = app.exec["start"]
    Log.info "executing command", exec_start

    if port = app.get_config("port")
      Log.info "listening on port", port.to_s
    end
    Exec.run cmd: exec_start,
      env: env_vars,
      output: Log.output,
      error: Log.error,
      chdir: app.path, &.wait
  end

  def config_get(prefix, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      if nopkg && path == "."
        Log.output.puts app.config!.data
      else
        Log.output.puts app.config!.get path
      end
    elsif path == "."
      app.each_config_key do |key|
        Log.output << key << ": " << app.get_config(key) << '\n'
      end
    else
      Log.output.puts app.get_config path
    end
  end

  def config_set(prefix, nopkg : Bool, application, path, value, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      app.config!.set path, value
    else
      app.set_config path, value
    end
  end

  def config_del(prefix, nopkg : Bool, application, path, **args)
    app = Prefix.new(prefix).new_app application
    if nopkg
      app.config!.del path
    else
      app.del_config path
    end
  end
end
