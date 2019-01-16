require "uri"
require "./database/*"
require "./prefix"
require "./main_config"

module Database
  extend self

  def self.supported?(database : String) : Bool
    {"mysql"}.includes? database
  end

  def create(prefix : Prefix, user : String, database_application : Prefix::App) : MySQL
    user = '_' + user
    host = database_application.get_config("host").to_s
    port = database_application.get_config("port").to_s

    uri = URI.new(
      scheme: nil,
      host: host,
      port: port.to_i,
      path: nil,
      query: nil,
      user: "root",
      password: database_application.password,
    )

    case provide = database_application.pkg_file.provides
    when "mysql" then MySQL.new uri, user
    else              new_database uri, user, database_application.pkg_file.package
    end
  end

  def new_database(uri : URI, user : String, name : String) : MySQL
    case name
    when "mysql" then MySQL.new uri, user
    else              raise "unsupported database: #{name}"
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
