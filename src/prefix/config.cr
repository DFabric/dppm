module Prefix::Config
  class_property file : String = "./config.con"

  class_getter data : CON::Any { self.read }
  class_getter mirror : String { data["mirror"].as_s }
  class_getter source : String { data["source"].as_s }
  class_getter host : String { data["host"].as_s }
  class_getter port : String { data["port"].as_s }

  def self.read
    @@data = if File.exists? @@file
               CON.parse File.read(@@file)
             else
               CON.parse {{ read_file "./config.con" }}
             end
  end

  def self.write
    if data = @@data
      File.write @@file, data.to_pretty_con
    end
  end
end
