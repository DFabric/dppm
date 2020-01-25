abstract class Service::Config
  property user : String? = nil,
    group : String? = nil,
    directory : String? = nil,
    command : String? = nil,
    reload_signal : String? = nil,
    description : String? = nil,
    log_output : String? = nil,
    log_error : String? = nil,
    env_vars : Hash(String, String) = Hash(String, String).new,
    after : Set(String) = Set(String).new,
    want : Set(String) = Set(String).new,
    umask : String? = "007",
    restart_delay : UInt32? = 9_u32

  abstract def build(io : IO)

  def parse_env_vars(env_vars : String)
    env_vars.rchop.split("\" ").each do |env|
      var, _, val = env.partition "=\""
      @env_vars[var] = val
    end
  rescue
    # the PATH is not set/corrupt - make a new one from what we have parsed
  end

  def build_env_vars : String
    String.build { |str| build_env_vars str }
  end

  def build_env_vars(io)
    start = true
    @env_vars.each do |variable, value|
      io << ' ' if !start
      io << variable << "=\"" << value << '"'
      start = false
    end
  end
end
