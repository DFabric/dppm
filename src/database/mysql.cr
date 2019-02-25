require "mysql"

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

  def check_connection
    open { }
  end

  def check_user
    open do |db|
      db.unprepared("SELECT User FROM mysql.user WHERE User = '#{@user}'").query do |rs|
        raise DatabasePresentException.new(@uri, @user) if database_exists? db, @user
        rs.each do
          raise UserPresentException.new(@uri, @user) if database_exists? db, @user
        end
      end
    end
  end

  def set_root_password : String
    password = Database.gen_password
    open do |db|
      db.unprepared("ALTER USER 'root'@'%' IDENTIFIED BY '#{password}'").exec
      flush db
    end
    @uri.password = password
  end

  def create(password : String)
    open do |db|
      db.unprepared("CREATE DATABASE #{@user}").exec
      db.unprepared("GRANT USAGE ON *.* TO '#{@user}'@'#{@uri.hostname}' IDENTIFIED BY '#{password}'").exec
      db.unprepared("GRANT ALL PRIVILEGES ON #{@user}.* TO '#{@user}'@'#{@uri.hostname}'").exec
      flush db
    rescue ex
      delete
      raise ex
    end
  end

  def clean
    open do |db|
      db.unprepared("SELECT user, host FROM mysql.user").query do |rs|
        rs.each do
          user = rs.read String
          hostname = rs.read String
          if user.starts_with?('_') && !database_exists? db, user
            db.unprepared("DROP USER '#{user}'@'#{hostname}'").exec
          end
        end
      end
      flush db
    end
  end

  def delete
    open do |db|
      db.unprepared("DROP DATABASE IF EXISTS #{@user}").exec
    end
  end

  def open(&block : DB::Database ->)
    DB.open @uri do |db|
      yield db
    end
  rescue ex : DB::Error
    raise ConnectionError.new @uri, ex
  end

  def flush(db : DB::Database)
    db.unprepared("FLUSH PRIVILEGES").exec
  end
end
