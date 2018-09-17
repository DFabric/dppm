struct Service::Env
  # Environment variables need to be in the format `PATH="/usr/bin:/bin" ENV="some value"`
  def initialize(env_vars : String)
    @env_vars = Hash(String, String).new
    begin
      env_vars.rchop.split("\" ").each do |env|
        var, val = env.split("=\"")
        @env_vars[var] = val
      end
    rescue
      # the PATH is not set/corrupt - make a new one from what we have parsed
    end
  end

  def initialize(env_vars)
    @env_vars = Hash(String, String).new
  end

  def set(var : String, value : String) : String
    # If the var exists
    @env_vars[var] = value

    String.build do |str|
      @env_vars.each do |var, value|
        str << ' ' << var << "=\"" << value << '"'
      end
    end.lchop
  end

  def get(var : String) : String
    (var = @env_vars[var]?) ? var : raise "can't get #{var} from #{@env_vars}"
  end
end
