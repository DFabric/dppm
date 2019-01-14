require "mysql"

struct Database::MySQL
  include Base

  def initialize(@uri : URI, @user : String)
    @uri.scheme = "mysql"
  end

  def check
    DB.open @uri do |db|
      db.unprepared("SHOW DATABASES LIKE '#{@user}'").query do |rs|
        rs.each do
          database_exists_error
        end
      end
      db.unprepared("SELECT User FROM mysql.user WHERE User = '#{@user}'").query do |rs|
        rs.each do
          users_exists_error
        end
      end
    end
  rescue ex : DB::Error
    raise "can't open database: #{@uri}"
  end

  def create(password : String)
    DB.open @uri do |db|
      db.unprepared("CREATE DATABASE #{@user}").exec
      db.unprepared("GRANT USAGE ON *.* TO '#{@user}'@'#{@uri.host}' IDENTIFIED BY '#{password}'").exec
      db.unprepared("GRANT ALL PRIVILEGES ON #{@user}.* TO '#{@user}'@'#{@uri.host}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    rescue ex
      delete
      raise ex
    end
  end

  def delete
    DB.open @uri do |db|
      db.unprepared("DROP DATABASE IF EXISTS #{@user}").exec
      db.unprepared("DROP USER IF EXISTS '#{@user}'@'#{@uri.host}'").exec
      db.unprepared("FLUSH PRIVILEGES").exec
    end
  end
end
