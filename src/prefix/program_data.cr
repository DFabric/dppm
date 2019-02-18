require "./base"
require "./program_data_task"

module Prefix::ProgramData
  include Base

  record Lib, relative_path : String, pkg : Prefix::Pkg, config : Config::Types?

  getter bin_path : String

  getter all_bin_paths : Array(String) do
    paths = [bin_path]
    libs.each do |library|
      paths << library.pkg.bin_path
    end
    paths
  end

  getter data_dir : String do
    @path + "data/"
  end

  getter app_path : String do
    @path + "app"
  end

  getter libs : Array(Lib) do
    libs = Array(Lib).new
    return libs if !Dir.exists? libs_dir

    Dir.each_child libs_dir do |lib_package|
      relative_path = libs_dir + lib_package
      lib_pkg = @prefix.new_pkg File.basename(File.real_path(relative_path))
      config_file = nil
      if Dir.exists?(conf_libs_dir = conf_dir + lib_pkg.package)
        Dir.each_child conf_libs_dir do |file|
          config_file = Config.new? File.new(conf_libs_dir + '/' + file)
        end
      end
      libs << Lib.new relative_path, lib_pkg, config_file
    end

    libs
  end
end
