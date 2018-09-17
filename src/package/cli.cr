struct Package::CLI
  @vars = Hash(String, String).new
  @no_confirm = false

  def initialize
  end

  {% for task in %w(add build delete) %}
  def {{task.id}}(@no_confirm, config, mirror, pkgsrc, prefix, package, custom_vars
                 {% if task == "add" %}, contained, noservice, socket
                 {% elsif task == "delete" %}, keep_owner{% end %})
    Log.info "initializing", {{task}}
    @vars["package"] = package
    @vars["prefix"] = prefix

    # configuration
    begin
      configuration = INI.parse(File.read config || CONFIG_FILE)

      @vars["pkgsrc"] = pkgsrc || configuration["main"]["pkgsrc"]
      @vars["mirror"] = mirror || configuration["main"]["mirror"]
    rescue ex
      raise "configuraration error: #{ex}"
    end

    vars_parser custom_vars

    # Update cache
    Cache.update @vars["pkgsrc"], ::Package::Path.new(prefix, create: true).src

    # Create task
    @vars.merge! ::System::Host.vars
    task = {{task.camelcase.id}}.new(@vars,
    {% if task == "add" %}
       shared: !contained, add_service: !noservice, socket: socket
    {% elsif task == "delete" %}
      keep_owner: keep_owner
    {% end %})

    Log.info {{task}}, task.simulate
    task.run if @no_confirm || ::Package.confirm
  end
  {% end %}

  def vars_parser(variables : Array(String))
    variables.each do |arg|
      case arg
      when .includes? '='
        key, value = arg.split '=', 2
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !Utils.ascii_alphanumeric_underscore? key
        @vars[key] = value
      else
        raise "invalid variable: #{arg}"
      end
    end
  end
end
