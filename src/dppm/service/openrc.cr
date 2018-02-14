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

  def writable?
    File.writable? "/etc/init.d/"
  end

  def name
    "OpenRC"
  end

  def log
    # "/var/log/" + service + ".log"
  end
end
