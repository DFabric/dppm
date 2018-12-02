struct Manager::MainConfig
  FILE = "./config.con"
  getter file : String,
    mirror : String,
    source : String

  def initialize(file : String? = nil, mirror : String? = nil, source : String? = nil)
    @file = file || FILE
    # TODO: Replace CON::Any by CON::Serializable
    any = CON.parse File.read(@file)
    @mirror = mirror || any["mirror"].as_s
    @source = source || any["source"].as_s
  end
end
