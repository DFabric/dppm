module Service::Env
  extend self

  # Environment variables need to be in the format `PATH="/usr/bin:/bin" ENV="some value"`
  private def parse_vars(env_vars)
    h = Hash(String, String).new
    if !env_vars.empty? && env_vars.is_a? String
      env_vars[0..-2].split("\" ").each do |env|
        var, val = env.split("=\"")
        h[var] = val
      end
    end
    h
  end

  def set(env_vars, var, value)
    # If the var exists
    vars = if env_vars.is_a? String
             parse_vars env_vars
           else
             Hash(String, String).new
           end
    vars[var] = value

    String.build do |str|
      vars.each do |var, value|
        str << ' ' << var << "=\"" << value << '"'
      end
    end.lchop
  end

  def get(env_vars, var)
    vars = parse_vars env_vars
    vars[var]? ? vars[var] : raise "can't get #{var} from #{env_vars}"
  end
end
