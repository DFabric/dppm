module Service::Env
  extend self

  def set(env_vars, var, value)
    # If the var exists
    if env_vars =~ /(^| )#{var}=[^ ]+/
      env_vars.scan(/([^ ]+?)=([^ ]+)/m).map do |env_var|
        env_var[1] == var ? var + '=' + value : env_var[0]
      end.join ' '
    elsif env_vars =~ /^(?:[ ]+)?$/
      var + '=' + value
    else
      "#{env_vars} #{var}=#{value}"
    end
  end

  def get(env_vars, var)
    env_vars =~ /(^| )#{var}=([^ ]+)/
    $2 ? $2 : raise "can't get #{var} from #{env_var}"
  end
end
