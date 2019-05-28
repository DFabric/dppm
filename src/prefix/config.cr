struct DPPM::Prefix::Config
  getter sources : Hash(String, String) { data["sources"].as_h.transform_values &.as_s }
  getter host : String { data["host"].as_s }
  getter port : Int32 { data["port"].as_i }
  getter data : CON::Any

  def initialize(content : String)
    @data = CON.parse content
  end
end
