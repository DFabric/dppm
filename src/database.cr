require "uri"
require "random"
require "./database/*"

module DPPM::Database
  extend self

  class ConnectionError < Exception
    def self.new(uri : URI, cause : Exception)
      new "Can't connect to the database: #{uri}", cause
    end
  end

  class DatabasePresentException < Exception
    def self.new(uri : URI, user : String)
      new "Database already present in #{uri.scheme}: " + user
    end
  end

  class UserPresentException < Exception
    def self.new(uri : URI, user : String)
      new "User already present in #{uri.scheme}: " + user
    end
  end

  def self.supported?(database : String) : Bool
    {"mysql"}.includes? database
  end

  def self.new(uri : URI, user : String, name : String) : MySQL
    case name
    when "mysql" then MySQL.new uri, user
    else              raise "Unsupported database: " + name
    end
  end

  def gen_password : String
    # MySQL requires to have at least one special character
    password = Random::Secure.urlsafe_base64
    password.each_char do |char|
      return password if !char.ascii_alphanumeric?
    end
    gen_password
  end
end
