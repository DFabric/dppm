require "mysql"

# Temporary fix

class MySql::Connection < DB::Connection
  def initialize(context : DB::ConnectionContext)
    super(context)
    @socket = uninitialized TCPSocket

    begin
      host = context.uri.hostname.not_nil!
      port = context.uri.port || 3306
      username = context.uri.user
      password = context.uri.password

      path = context.uri.path
      if path && path.size > 1
        initial_catalog = path[1..-1]
      else
        initial_catalog = nil
      end

      @socket = TCPSocket.new(host, port)
      handshake = read_packet(Protocol::HandshakeV10)

      write_packet(1) do |packet|
        Protocol::HandshakeResponse41.new(username, password, initial_catalog, handshake.auth_plugin_data).write(packet)
      end

      read_ok_or_err do |packet, status|
        raise "packet #{status} not implemented"
      end
    rescue Errno
      raise DB::ConnectionRefused.new
    end
  end
end

struct Database::MySQL
  include Base

  def initialize(@uri : URI, @user : String)
    @uri.scheme = "mysql"
  end

  private def database_exists?(db : DB::Database, database : String)
    db.unprepared("SHOW DATABASES LIKE '#{@user}'").query do |rs|
      rs.each do
        return true
      end
    end
    false
  end

  def check
    DB.open @uri do |db|
      db.unprepared("SELECT User FROM mysql.user WHERE User = '#{@user}'").query do |rs|
        database_exists_error if database_exists? db, @user
        rs.each do
          users_exists_error
        end
      end
    end
  rescue ex : DB::Error
    raise "can't connect to the database: #{@uri}"
  end

  def set_root_password : String
    password = Database.gen_password
    DB.open @uri do |db|
      db.unprepared("ALTER USER 'root'@'%' IDENTIFIED BY '#{password}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    end
    @uri.password = password
  end

  def create(password : String)
    DB.open @uri do |db|
      db.unprepared("CREATE DATABASE #{@user}").exec
      db.unprepared("GRANT USAGE ON *.* TO '#{@user}'@'#{@uri.hostname}' IDENTIFIED BY '#{password}'").exec
      db.unprepared("GRANT ALL PRIVILEGES ON #{@user}.* TO '#{@user}'@'#{@uri.hostname}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    rescue ex
      delete
      raise ex
    end
  end

  def clean
    DB.open @uri do |db|
      db.unprepared("SELECT user, host FROM mysql.user").query do |rs|
        rs.each do
          user = rs.read String
          hostname = rs.read String
          if user.starts_with?('_') && !database_exists? db, user
            db.unprepared("DROP USER '#{user}'@'#{hostname}'").exec
          end
        end
      end
      db.unprepared("FLUSH PRIVILEGES").exec
    end
  end

  def delete
    DB.open @uri do |db|
      db.unprepared("DROP DATABASE IF EXISTS #{@user}").exec
    end
  end
end
