require "con"

struct Prefix::PkgFile
  # Supported application types.
  enum Type
    HTML
    HTTP
    Lib
    PHP
    TCP
    TCP_UDP
    UDP

    def self.new(type : String)
      case type
      when "HTML"    then HTML
      when "HTTP"    then HTTP
      when "lib"     then Lib
      when "PHP"     then PHP
      when "TCP"     then TCP
      when "TCP/UDP" then TCP_UDP
      when "UDP"     then UDP
      else                raise "unknow package type: " + type
      end
    end

    def to_s : String
      case self
      when Lib     then "lib"
      when TCP_UDP then "TCP/UDP"
      else              value.to_s
      end
    end

    # Returns `true` if the type is usually used along with an url.
    def use_url? : Bool
      case self
      when HTML, HTTP, PHP then true
      else                      false
      end
    end
  end

  getter package : String,
    name : String,
    type : Type,
    license : String,
    url : String,
    docs : String,
    description : String,
    info : String,
    provides : String?,
    config_export : String?,
    config_import : String?,
    config_origin : String?,
    config_vars : Hash(String, String)?,
    exec : Hash(String, String)?,
    aliases : Hash(String, String)?,
    deps : Hash(String, String)?,
    env : Hash(String, String)?,
    databases : Hash(String, String?)?,
    tasks : Hash(String, Array(CON::Any))?,
    shared : Bool?,
    ipv6_braces : Bool?,
    version : CON::Any,
    tags : CON::Any,
    any : CON::Any,
    config : Config?

  # Returns the `pkg.con` file path.
  getter path : Path do
    @root_path / "pkg.con"
  end

  protected def path=(@path : Path?) : Path?
  end

  protected property root_path : Path

  macro finished
  def initialize(@root_path : Path)
    raise "package directory doesn't exist: " + @root_path.to_s if !Dir.exists? @root_path.to_s

    # TODO: Replace CON::Any by CON::Serializable
    @any = CON.parse File.read(path)

    {% for string in %w(name package license url docs description info) %}\
    @{{string.id}} = @any[{{string}}].as_s
    {% end %}
    @type = Type.new @any["type"].as_s
    @version = @any["version"]
    @tags = @any["tags"]
    if provides = @any["provides"]?
      @provides = provides.as_s
    end
    @shared = if shared = @any["shared"]?
                shared.as_bool?
              end
    @ipv6_braces = if ipv6_braces = @any["ipv6_braces"]?
                     ipv6_braces.as_bool?
                   end

    {% for hash in %w(deps aliases env exec) %}\
    if {{hash.id}} = @any[{{hash}}]?
      @{{hash.id}} = {{hash.id}}.as_h.transform_values &.as_s
    end
    {% end %}
    if tasks = @any["tasks"]?
      @tasks = tasks.as_h.transform_values &.as_a
    end
    if databases = @any["databases"]?
      @databases = databases.as_h.transform_values &.as_s?
    end

    if (config_any = @any["config"]?) && (config = config_any.as_h?)
      if vars = config_any["vars"]?
        @config_vars = vars.as_h.transform_values &.as_s
      end
      {% for string in %w(export import origin) %}\
      if {{string.id}}_any = config[{{string}}]?
        @config_{{string.id}} = {{string.id}}_any.as_s
      end
      {% end %}
      if @config_import && !@config_origin
        raise "config.import requires config.origin to be set"
      end
    end
  end
  end

  def each_version(arch : String = Host.arch, kernel : String = Host.kernel, &block : String ->)
    # Set src and regex
    if hash = @version["self"]?
      src = hash["src"]?
      regex = hash["regex"]?
    end

    if version_kernel = @version[kernel]?
      if !regex
        raise "unsupported architecure: " + arch if !src
        regex = version_kernel[arch]
      end
    elsif !src && !regex
      raise "unsupported kernel: " + kernel
    end

    if src
      if src_array = src.as_a?
        src_array.each do |version|
          yield version.as_s
        end
      else
        HTTPHelper.get_string(src.to_s).each_line do |line|
          yield $0 if line =~ /#{regex}/
        end
      end
    else
      raise "no source url"
    end
  end

  def version_from_tag(tag : String) : String
    src = @tags[tag]["src"].as_s
    # Test if the src is an URL or a version number
    if HTTPHelper.url? src
      regex = if regex_tag = @tags[tag]["regex"]?
                regex_tag
              else
                @tags["self"]["regex"]
              end.as_s

      if version = /(#{regex})/.match(HTTPHelper.get_string src).try &.[1]?
        version
      else
        raise "can't match the regex `#{regex}` with the data from the url `#{src}`"
      end
    else
      src
    end
  end

  # Ensure the version number is available
  def ensure_version(version : String) : String
    available_version = false
    each_version do |ver|
      if version == ver
        available_version = true
        break
      end
    end
    raise "no available version number: " + version if !available_version
    version
  end
end
