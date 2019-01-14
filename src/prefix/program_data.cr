require "./base"

module Prefix::ProgramData
  include Base

  getter libs_dir : String do
    @path + "lib/"
  end

  getter data_dir : String do
    @path + "srv/"
  end

  getter app_path : String do
    @path + "app"
  end
end
