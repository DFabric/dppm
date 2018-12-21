require "./base"

module Prefix::ProgramData
  include Base

  @lib : String? = nil
  @data : String? = nil
  @app_dir : String? = nil

  def lib : String
    @lib ||= @path + "lib"
  end

  def data : String
    @data ||= @path + "srv"
  end

  def app_dir : String
    @app_dir ||= @path + "app"
  end
end
