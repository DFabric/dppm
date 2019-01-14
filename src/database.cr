require "uri"
require "./database/*"
require "./prefix"

module Database
  extend self

  def self.new(user : String, type : String, host : String, port : Int32) : MySQL | Nil
    uri = self.root_connection_uri host, port
    new_database? uri, user, type
  end

  def create(prefix : Prefix, user : String, database_application : String) : MySQL | Nil
    app = prefix.new_app database_application
    host = app.get_config("host").to_s.lstrip('[').rstrip(']')
    port = app.get_config("port").to_s.to_i

    uri = self.root_connection_uri host, port

    case provide = app.pkg_file.provides
    when "mysql" then MySQL.new uri, user
    else              new_database uri, user, app.pkg_file.package
    end
  end

  def new_database?(uri : URI, user : String, name : String) : MySQL | Nil
    case name
    when "mysql" then MySQL.new uri, user
    end
  end

  def new_database(uri : URI, user : String, name : String) : MySQL
    new_database(uri, user, name) || raise "unsupported database: #{name}"
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

  def root_connection_uri(host : String, port : Int32) : URI
    URI.new(
      scheme: nil,
      host: host,
      port: port,
      path: nil,
      query: nil,
      user: "root",
      password: nil,
    )
  end
end
