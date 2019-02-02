require "./base"

module Prefix::ProgramData
  include Base

  getter bin_path : String

  getter data_dir : String do
    @path + "srv/"
  end

  getter app_path : String do
    @path + "app"
  end
end
