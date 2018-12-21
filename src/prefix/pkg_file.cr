require "con"

struct Prefix::PkgFile
  getter package_version : String,
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

  @path : String? = nil

  def path : String
    @path ||= @root_dir + "pkg.con"
  end

  protected def path=(@path : String?) : String?
  end

  protected property root_dir : String

  macro finished
  def initialize(@root_dir : String)
    raise "package directory doesn't exists: " + @root_dir if !Dir.exists? @root_dir
    @package_version = File.basename(File.dirname(File.real_path(path))).split('_').last

    Log.info "parsing package informations", path
    # TODO: Replace CON::Any by CON::Serializable
    @any = CON.parse File.read(path)

    {% for string in %w(name package type license url docs description info) %}\
    @{{string.id}} = @any[{{string}}].as_s
    {% end %}
    @version = @any["version"]
    @tags = @any["tags"]
    @shared = if shared = @any["shared"]?
                shared.as_bool?
              end
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
