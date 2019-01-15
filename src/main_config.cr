require "con"

struct MainConfig
  @@data : CON::Any? = nil

  class_property file : String = "./config.con"

  class_getter mirror : String do
    data = @@data || self.read
    data["mirror"].as_s
  end

  class_getter source : String do
    data = @@data || self.read
    data["source"].as_s
  end

  def self.read
    @@data = CON.parse File.read(@@file)
  end

  def self.write
    if data = @@data
      File.write @@file, data.to_pretty_con
    end
  end
end
