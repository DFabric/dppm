class Service::Systemd::Config
  def build
    # Transform the hash to a systemd service
    systemd = Hash(String, Hash(String, String)).new
    @section.each do |section, content|
      content.each do |k, v|
        systemd[section] = Hash(String, String).new if !systemd[section]?
        # systemd[section][k] = v
        systemd[section][k] = v.is_a?(Array) ? v.join(' ') : v
      end
    end
    INI.build systemd
  end
end
