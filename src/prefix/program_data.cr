require "./base"

module Prefix::ProgramData
  include Base

  @libs_dir : String? = nil
  @data_dir : String? = nil
  @app_path : String? = nil

  def libs_dir : String
    @libs_dir ||= @path + "lib/"
  end

  def data_dir : String
    @data_dir ||= @path + "srv/"
  end

  def app_path : String
    @app_path ||= @path + "app"
  end
end
