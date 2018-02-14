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
