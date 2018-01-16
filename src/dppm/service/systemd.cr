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

  # [Unit]
  # Description=The PHP FastCGI Process Manager
  # After=network.target
  #
  # [Service]
  # Type=notify
  # PIDFile=run/php-fpm.pid
  # ExecStart=lib/php/php-fpm --nodaemonize --fpm-config /php-fpm.conf
  # ExecReload=/bin/kill -USR2 $MAINPID
  # PrivateTmp=true
  #
  # [Install]
  # WantedBy=multi-user.target

  def writable?
    File.writable? "/etc/systemd/system/"
  end

  def name
    "systemd"
  end

  def log
    # "journalctl --no-pager -oshort -u " + service
  end
end
