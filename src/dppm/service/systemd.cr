module Service::Systemd
  extend self
  include Service

  def system
    System
  end

  def config
    Config
  end

  def create(pkg, vars)
    sysinit_hash = creation Config.new(vars["pkgdir"] + "/etc/init/systemd", file: true), pkg, vars

    # pid is needed for php-fpm based applications
    # sysinit_hash.set "pidfile", "/run/#{vars["name"]}.pid" if "php-fpm"

    # systemd 236 and more supports file logging
    if version >= 236
      sysinit_hash.section["Service"]["StandardOutput"] = "file:#{vars["pkgdir"]}/log/out.log"
      sysinit_hash.section["Service"]["StandardError"] = "file:#{vars["pkgdir"]}/log/err.log"
    else
      Log.warn "file logging not supported", "systemd version '#{version}' too old (>=336 needed)"
    end

    # Convert back hashes to service files
    File.write vars["pkgdir"] + "/etc/init/systemd", sysinit_hash.build
  end

  def writable?
    File.writable? "/etc/systemd/system/"
  end

  def name
    "systemd"
  end

  def version
    Exec.new("/bin/systemctl", ["--version"]).out.match(/ ([0-9]+)\n/).not_nil![1].to_i
  end

  def log
    # "journalctl --no-pager -oshort -u " + service
  end
end
