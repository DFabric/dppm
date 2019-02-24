require "con"

struct MainConfig
  class_property file : String = "./config.con"

  class_getter data : CON::Any do
    self.read
  end

  class_getter mirror : String do
    data["mirror"].as_s
  end

  class_getter source : String do
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
