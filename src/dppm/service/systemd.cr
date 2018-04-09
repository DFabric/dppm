module Service::Systemd
  extend self
  include Service

  def system
    System
  end

  def config
    Config
  end

  def create(pkg, vars, &log : String, String, String -> Nil)
    sysinit_hash = creation Config.new(vars["pkgdir"] + "/etc/init/systemd", file: true), pkg, vars, &log

    # pid is needed for php-fpm based applications
    sysinit_hash.set "pidfile", "/run/#{vars["name"]}.pid" if pkg["keywords"].includes? "php-fpm"

    # systemd 336 and more supports file logging
    begin
      if version >= 336
        sysinit_hash.section["Service"]["StandardOutput"] = "file:#{vars["pkgdir"]}/log/out.log"
        sysinit_hash.section["Service"]["StandardError"] = "file:#{vars["pkgdir"]}/log/err.log"
      else
        log.call "WARN", "file logging not supported", "systemd version '#{version}' too old (>=336 needed)"
      end
    ensure
      # Convert back hashes to service files
      File.write vars["pkgdir"] + "/etc/init/systemd", sysinit_hash.build
    end
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
