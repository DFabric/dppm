require "./system"
require "./systemd/*"

module Service::Systemd
  extend self
  include Cli
  include Init

  def system
    System
  end

  def config
    Config
  end

  def create(pkg, vars)
    sysinit_hash = creation Config.new(vars["pkgdir"] + "/etc/init/systemd", file: true), pkg, vars

    # systemd 236 and more supports file logging
    if version >= 236
      sysinit_hash.section["Service"]["StandardOutput"] = "file:#{vars["pkgdir"]}/" + LOG_OUTPUT_PATH
      sysinit_hash.section["Service"]["StandardError"] = "file:#{vars["pkgdir"]}/" + LOG_ERROR_PATH
    else
      Log.warn "file logging not supported", "systemd version '#{version}' too old (>=336 needed)"
    end

    # Convert back hashes to service files
    File.write vars["pkgdir"] + "/etc/init/systemd", sysinit_hash.build
  end

  def name
    "systemd"
  end

  def version : Int32
    Exec.new("/bin/systemctl", ["--version"]).out =~ / ([0-9]+)\n/
    $1.to_i
  rescue ex
    raise "can't retrieve the OpenRC version: #{ex}"
  end
end
