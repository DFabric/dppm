module Service::OpenRC
  extend self
  include Service

  def base
    {"pidfile"               => "/run/${RC_SVCNAME}.pid",
     "supervisor"            => "supervise-daemon",
     "supervise_daemon_args" => {
       "stdout" => "log/out.log",
       "stderr" => "log/err.log",
     },
     "depend" => {
       "after" => ["net"],
     },
     "reload" => ["eerror \"Reloading not available for $RC_SVCNAME\""]}
  end

  def create(pkg, vars, &log : String, String, String -> Nil)
    # Convert back hashes to service files
    File.write vars["pkgdir"] + "etc/init/openrc", OpenRC.build Service.create("OpenRC", pkg, vars, &log)
  end

  def writable?
    File.writable? "/etc/init.d/"
  end

  def name
    "OpenRC"
  end

  def version
    Exec.new("/sbin/openrc", ["-V"]).out.match(/([0-9]+\.[0-9]+\.[0-9]+)/).not_nil![1]
  end

  def log
    # "/var/log/" + service + ".log"
  end
end
