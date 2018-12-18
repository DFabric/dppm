require "./system"

struct Service::Systemd
  include System
  class_getter type : String = "systemd"

  def initialize(@name : String)
    @file = if File.exists?(service = "/lib/systemd/system/#{@name}.service")
              service
            else
              "/etc/systemd/system/#{@name}.service"
            end
    @boot_file = "/etc/systemd/system/multi-user.target.wants/#{@name}.service"
    @init_path = Service::ROOT_PATH + @@type.downcase
  end

  def config
    Config
  end

  private def finalize_create(pkgdir : String, sysinit_hash)
    # systemd 236 and more supports file logging
    if Systemd.version >= 236
      sysinit_hash.section["Service"]["StandardOutput"] = "file:#{pkgdir}/" + LOG_OUTPUT_PATH
      sysinit_hash.section["Service"]["StandardError"] = "file:#{pkgdir}/" + LOG_ERROR_PATH
    else
      Log.warn "file logging not supported", "systemd version '#{Systemd.version}' too old (>=336 needed)"
    end
  rescue ex
    Log.warn "file logging not supported", ex.to_s
  end

  def self.each
    Dir["/lib/systemd/system/*.service", "/etc/systemd/system/*.service"].each do |service|
      yield File.basename(service)[0..-9]
    end
  end

  def run?
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", "is-active", @name}
  end

  def delete : Bool
    delete_internal
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  def enable(pkgdir) : Bool
    File.symlink pkgdir + @init_path, @file
    Service.exec? "/bin/systemctl", {"--no-ask-password", "daemon-reload"}
  end

  {% for action in %w(start stop restart reload) %}
  def {{action.id}} : Bool
    Service.exec? "/bin/systemctl", {"-q", "--no-ask-password", {{action}}, @name}
  end
  {% end %}

  def self.version : Int32
    output, error = Exec.new "/bin/systemctl", {"--version"}, &.wait
    if output.to_s =~ / ([0-9]+)\n/
      $1.to_i
    else
      raise "can't retrieve the systemd version: #{output}#{error}"
    end
  end
end

require "./systemd/*"
