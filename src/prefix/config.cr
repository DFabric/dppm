struct DPPM::Prefix::Config
  getter sources : Hash(String, String)
  getter host : String
  getter port : Int32

  def initialize(data : String | IO)
    data = CON.parse data
    @port = data["port"].as_i
    @host = data["host"].as_s
    @sources = data["sources"].as_h.transform_values &.as_s
  end
end
