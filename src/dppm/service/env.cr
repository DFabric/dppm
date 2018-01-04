module Service
  def set_env(env_vars, var, value)
    # If the var exists
    if env_vars =~ /(^| )#{var}=[^ ]+/
      env_vars.scan(/([^ ]+?)=([^ ]+)/m).map do |env_var|
        env_var[1] == var ? var + '=' + value : env_var[0]
      end.join ' '
    elsif env_vars =~ /^(?:[ ]+)?$/
      var + '=' + value
    else
      env_vars + ' ' + var + '=' + value
    end
  end

  def get_env(env_vars, var)
    env_vars.match(/(^| )#{var}=([^ ]+)/).not_nil![2]
  end
end
