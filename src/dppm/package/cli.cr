struct Package::CLI
  @vars = Hash(String, String).new
  @noconfirm = false

  def initialize
  end

  {% for task in %w(add build delete) %}
  def {{task.id}}(@noconfirm, config, mirror, pkgsrc, prefix, package, custom_vars {% if task == "add" %}, contained, noservice, socket{% end %})
    Log.info "initializing", {{task}}
    @vars["package"] = package
    @vars["prefix"] = prefix

    # configuration
    begin
      configuration = INI.parse(File.read config ? config : CONFIG_FILE)

      @vars["pkgsrc"] = pkgsrc ? pkgsrc : configuration["main"]["pkgsrc"]
      @vars["mirror"] = mirror ? mirror : configuration["main"]["mirror"]
    rescue ex
      raise "configuraration error: #{ex}"
    end

    vars_parser custom_vars

    # Update cache
    Cache.update @vars["pkgsrc"], ::Package::Path.new(prefix, create: true).src

    # Create task
    @vars.merge! Localhost.vars
    {% if task == "add" %}
      task = {{task.camelcase.id}}.new @vars, shared: !contained, add_service: !noservice, socket: socket
    {% else %}
      task = {{task.camelcase.id}}.new @vars
    {% end %}

    # puts task.class.to_s.split("::").last.downcase
    Log.info {{task}}, task.simulate
    task.run if @noconfirm || ::Package.confirm
  end
  {% end %}

  def vars_parser(variables : Array(String))
    variables.each do |arg|
      case arg
      when .includes? '='
        key, value = arg.split '=', 2
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !key.ascii_alphanumeric_underscore?
        @vars[key] = value
      else
        raise "invalid variable: #{arg}"
      end
    end
  end
end
