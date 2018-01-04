module Service::OpenRC
  extend self
  include Service

  def base
    {"pidfile"               => "/run/${RC_SVCNAME}.pid",
     "supervisor"            => "supervise-daemon",
     "supervise_daemon_args" => {
       "stdout" => "/var/log/${RC_SVCNAME}_out.log",
       "stderr" => "/var/log/${RC_SVCNAME}_err.log",
     },
     "depend" => {
       "after" => ["net"],
     },
     "reload" => ["eerror \"Reloading not available for $RC_SVCNAME\""]}
  end

  # !/sbin/openrc-run

  # description="PHP FastCGI Process Manager"
  #
  # start_stop_daemon_vars="--quiet"
  # pidfile="/run/$RC_SVCNAME/php-fpm.pid"
  #
  # supervisor="supervise-daemon"
  #
  # depend() {
  #   after net
  #   use apache2 lighttpd nginx
  # }
  #
  # reload() {
  # 	ebegin "Reloading $name"
  # 	start-stop-daemon --signal USR2 --pidfile "$pidfile"
  # 	eend $?
  # }
  #
  # reopen() {
  # 	ebegin "Reopening $name log files"
  # 	start-stop-daemon --signal USR1 --pidfile "$pidfile"
  #   eend $?
  # }

  def name
    "OpenRC"
  end

  def log
    # "/var/log/" + service + ".log"
  end
end
