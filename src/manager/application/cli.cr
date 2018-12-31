module Manager::Application::CLI
  extend self

  def delete(no_confirm, config, mirror, source, prefix, application, custom_vars, keep_user_group)
    Log.info "initializing", "delete"

    task = Delete.new application, Prefix.new(prefix), keep_user_group

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
    root_prefix = Prefix.new prefix, true
    Source::Cache.update root_prefix, main_config.source

    # Create task
    vars.merge! Host.vars
    task = Add.new vars, root_prefix, shared: !contained, add_service: !noservice, socket: socket

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

  def query(prefix, application, path, **args) : String
    pkg_file = Prefix.new(prefix).new_app(application).pkg_file
    Query.new(pkg_file.any).pkg(path).to_pretty_con
  end

  def version(prefix, application, **args) : String
    Prefix.new(prefix).new_app(application).version
  end

  def exec(prefix, application, **args)
    app = Prefix.new(prefix).new_app application

    if exec = app.pkg_file.exec
      exec_start = exec["start"].split(' ')
    else
      raise "exec key not present in #{app.pkg_file.path}"
    end
    env_vars = app.pkg_file.env || Hash(String, String).new
    env_vars["PATH"] = app.env_vars

    Process.run command: exec_start[0],
      args: (exec_start[1..-1] if exec_start[1]?),
      env: env_vars,
      clear_env: true,
      shell: false,
      output: STDOUT,
      error: STDERR,
      chdir: app.path
  end
end
