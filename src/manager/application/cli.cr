module Manager::Application::CLI
  extend self

  def delete(no_confirm, prefix, application, keep_user_group, preserve_database, **args)
    Prefix.new(prefix).new_app(application).delete !no_confirm, keep_user_group, preserve_database do
      Manager.cli_confirm
    end
  end

  def add(no_confirm, config, mirror, source, prefix, application, custom_vars, contained, noservice, socket, database = nil, url = nil, web_server = nil, debug = nil)
    vars = Hash(String, String).new
    Log.info "initializing", "add"
    MainConfig.file = config
    vars["mirror"] = mirror || MainConfig.mirror
    vars_parser custom_vars, vars

    # Update cache
    root_prefix = Prefix.new prefix, true
    root_prefix.update source

    # Create task
    vars.merge! Host.vars
    pkg = Prefix::Pkg.create root_prefix, application, vars["version"]?, vars["tag"]?
    deps = Set(Prefix::Pkg).new
    task = nil
    run = false
    pkg.build vars, deps, false do
      task = Add.new(
        pkg: pkg,
        vars: vars.dup,
        deps: deps,
        shared: !contained,
        add_service: !noservice,
        socket: socket,
        database: database,
        url: url,
        web_server: web_server
      )
      task.simulate
      if no_confirm || Manager.cli_confirm
        run = true
      end
    end
    task.not_nil!.run if run
    task.not_nil!.app
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

  def query(prefix, application, path, **args) : String
    pkg_file = Prefix.new(prefix).new_app(application).pkg_file
    Query.new(pkg_file.any).pkg(path).to_pretty_con
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
end
