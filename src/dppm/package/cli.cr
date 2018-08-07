struct Package::CLI
  @vars = Hash(String, String).new
  @noconfirm = false

  def initialize
  end

  {% for task in %w(add build delete) %}
  def {{task.id}}(@noconfirm, config, mirror, pkgsrc, prefix, package, variables {% if task == "add" %}, contained{% end %})
    Log.info "initializing", {{task}}
    @vars["package"] = package
    @vars["prefix"] = prefix
    {% if task == "add" %} @vars["contained"] = contained.to_s {% end %}

    # configuration
    begin
      configuration = INI.parse(File.read config ? config : CONFIG_FILE)

      @vars["pkgsrc"] = pkgsrc ? pkgsrc : configuration["main"]["pkgsrc"]
      @vars["mirror"] = mirror ? mirror : configuration["main"]["mirror"]
    rescue ex
      raise "configuraration error: #{ex}"
    end

    arg_parser variables

    # Update cache
    Package::Cache.update @vars["pkgsrc"], ::Package::Path.new(prefix, create: true).src

    task = {{task.camelcase.id}}.new @vars.merge! Localhost.vars

    # puts task.class.to_s.split("::").last.downcase
    Log.info {{task}}, task.simulate
    task.run if @noconfirm || ::Package.confirm
  end
  {% end %}

  def arg_parser(variables : Array(String))
    variables.each do |arg|
      case arg
      when .includes? '='
        var = arg.split '=', 2
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !var[0].ascii_alphanumeric_underscore?
        @vars[var[0]] = var[1]
      else
        raise "invalid variable: #{arg}"
      end
    end
  end
end
