require "con"
require "file_utils"

module DPPM
  DEFAULT_PATH = begin
    if Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end

  module Config
    class_property file : String = DEFAULT_PATH + "/config.con"

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
      if !File.exists? @@file
        FileUtils.mkdir_p DEFAULT_PATH
        File.write(@@file, {{ read_file "./config.con" }})
      end
      @@data = CON.parse File.read(@@file)
    end

    def self.write
      if data = @@data
        File.write @@file, data.to_pretty_con
      end
    end
  end
end

require "./cli"
CLI.run
