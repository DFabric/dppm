require "ini"

struct Service::Systemd::Config
  def space_array
    {"Unit"    => ["Requires", "Wants", "After", "Before", "Environment"],
     "Service" => [""],
     "Install" => ["WantedBy", "RequiredBy"]}
  end

  def initialize(data : String)
    @section = INI.parse data
  end
end
