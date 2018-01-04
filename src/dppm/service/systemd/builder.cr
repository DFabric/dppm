module Service::Systemd
  def build(data)
    # Transform the hash to a systemd service
    systemd = Hash(String, Hash(String, String)).new
    data.each do |section, keys|
      data[section].each do |k, v|
        systemd[section] = Hash(String, String).new if !systemd[section]?
        # systemd[section][k] = v
        systemd[section][k] = v.is_a?(Array) ? v.join(' ') : v
      end
    end
    INI.build systemd
  end
end
