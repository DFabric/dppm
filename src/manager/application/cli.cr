module Manager::Application::CLI
  extend self

  def delete(no_confirm, config, mirror, source, prefix, application, custom_vars, keep_user_group)
    Log.info "initializing", "delete"

    task = Delete.new application, prefix, keep_user_group

    Log.info "delete", task.simulate
    task.run if no_confirm || Manager.cli_confirm
  end

  def add(no_confirm, config, mirror, source, prefix, application, custom_vars, contained, noservice, socket)
    vars = Hash(String, String).new
    Log.info "initializing", "add"
    vars["package"] = application
    vars["prefix"] = prefix

    main_config = MainConfig.new config, mirror, source
    vars["mirror"] = main_config.mirror
    vars_parser custom_vars, vars

    # Update cache
    Source::Cache.update main_config.source, prefix

    # Create task
    vars.merge! Host.vars
    task = Add.new vars, shared: !contained, add_service: !noservice, socket: socket

    Log.info "add", task.simulate
    task.run if no_confirm || Manager.cli_confirm
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

  def query(prefix, application, path, **args)
    Query.new(Path.new(prefix).app + application).pkg path
  end

  def exec(prefix, application, **args)
    app_path = Path.new(prefix).app + application
    pkg_file = PkgFile.new app_path

    if exec = pkg_file.exec
      exec_start = exec["start"].split(' ')
    else
      raise "exec key not present in #{pkg_file.path}"
    end
    if env_vars = pkg_file.env
      env_vars["PATH"] = Path.env_var app_path
    end

    Process.run command: exec_start[0],
      args: (exec_start[1..-1] if exec_start[1]?),
      env: env_vars,
      clear_env: true,
      shell: false,
      output: STDOUT,
      error: STDERR,
      chdir: app_path
  end
end
