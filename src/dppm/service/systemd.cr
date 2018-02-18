module Service::Systemd
  extend self
  include Service

  def base
    {"Unit" => {
      "After" => "network.target",
    },
     "Service" => {
       "Type"    => "simple",
       "Restart" => "always",
     },
     "Install" => {
       "WantedBy" => "multi-user.target",
     }}
  end

  def create(pkg, vars, &log : String, String, String -> Nil)
    sysinit_hash = creation "Systemd", pkg, vars, &log

    # pid is needed for php-fpm based applications
    sysinit_hash = Systemd.set sysinit_hash, "pidfile", "/run/" + vars["package"] + ".pid" if pkg["keywords"].includes? "php-fpm"

    # systemd 336 and more supports file logging
    begin
      if version >= 336
        sysinit_hash["Service"]["StandardOutput"] = "file:" + vars["pkgdir"] + "log/out.log"
        sysinit_hash["Service"]["StandardError"] = "file:" + vars["pkgdir"] + "log/err.log"
      else
        log.call "WARN", "file logging not supported", "systemd version '#{version}' too old (>=336 needed)"
      end
    ensure
      # Convert back hashes to service files
      File.write vars["pkgdir"] + "etc/init/systemd", Systemd.build sysinit_hash
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
