require "uri"
require "./database/*"

module DPPM::Database
  extend self

  class ConnectionError < Exception
    def self.new(uri : URI, cause : Exception)
      new "can't connect to the database: #{uri}", cause
    end
  end

  class DatabasePresentException < Exception
    def self.new(uri : URI, user : String)
      new "database already present in #{uri.scheme}: " + user
    end
  end

  class UserPresentException < Exception
    def self.new(uri : URI, user : String)
      new "user already present in #{uri.scheme}: " + user
    end
  end

  def self.supported?(database : String) : Bool
    {"mysql"}.includes? database
  end

  def self.new(uri : URI, user : String, name : String) : MySQL
    case name
    when "mysql" then MySQL.new uri, user
    else              raise "unsupported database: " + name
    end
  end

  def gen_password : String
    # MySQL requires to have at least one special character
    while password = Utils.gen_password
      strong_password = false
      password.each_char do |char|
        if !char.ascii_alphanumeric?
          strong_password = true
          break
        end
      end
      break if strong_password
    end
    password
  end
end
