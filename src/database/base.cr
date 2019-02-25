module Database::Base
  getter uri : URI,
    user : String

  def ensure_root_password(database_app : Prefix::App)
    if !@uri.password
      File.write database_app.password_file, set_root_password
      File.chmod database_app.password_file, 0o400
    end
  end

  def vars
    {
      "database_address" => "#{@uri.host}:#{@uri.port}",
      "database_port"    => @uri.port.to_s,
      "database_host"    => @uri.hostname.not_nil!,
      "database_user"    => @user,
      "database_name"    => @user,
      "database_type"    => @uri.scheme.not_nil!,
    }
  end
end
