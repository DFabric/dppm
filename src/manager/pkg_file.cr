require "con"

struct Manager::PkgFile
  NAME = "/pkg.con"
  getter path : String,
    package : String,
    name : String,
    type : String,
    license : String,
    url : String,
    docs : String,
    description : String,
    info : String,
    deps : Hash(String, String)?,
    aliases : Hash(String, String)?,
    env : Hash(String, String)?,
    config : Hash(String, String)?,
    version : CON::Any,
    tags : CON::Any,
    databases : CON::Any?,
    tasks : CON::Any?,
    shared : Bool?,
    any : CON::Any
  property exec : Hash(String, String)?
  property dir : String

  macro finished
  def initialize(@dir : String)
    raise "package directory doesn't exists: " + @dir if !Dir.exists? @dir
    @path = @dir + NAME

    Log.info "parsing package informations", @path
    # TODO: Replace CON::Any by CON::Serializable
    @any = CON.parse File.read(@path)

    {% for string in %w(name package type license url docs description info) %}\
    @{{string.id}} = @any[{{string}}].as_s
    {% end %}
    @version = @any["version"]
    @tags = @any["tags"]
    @shared = @any["shared"].as_bool?
    {% for hash in %w(deps aliases env exec config) %}\
    if {{hash.id}}_any = @any[{{hash}}]?
      {{hash.id}} = Hash(String, String).new
      {{hash.id}}_any.as_h.each do |k, v|
        {{hash.id}}[k] = v.as_s
      end
      @{{hash.id}} = {{hash.id}}
    end
    {% end %}
    {% for any in %w(databases tasks) %}\
    @{{any.id}} = @any[{{any}}]?
    {% end %}
  end
  end
end
