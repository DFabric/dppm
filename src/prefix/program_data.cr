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

  def exists!
    raise "directory already exists: " + @path if exists?
    self
  end

  def exists?
    self if File.exists? @path
  end

  def install_deps(deps : Set(Pkg), vars : Hash(String, String), shared : Bool = true, &block)
    Log.info "bulding dependencies", libs_dir
    Dir.mkdir_p libs_dir

    # Build each dependency
    deps.each do |dep_pkg|
      dest_pkg_dep_dir = libs_dir + dep_pkg.package
      if !Dir.exists? dep_pkg.path
        Log.info "building dependency", dep_pkg.path
        dep_pkg.build vars.dup
      end
      if !File.exists? dest_pkg_dep_dir
        if shared
          Log.info "adding symlink to dependency", dep_pkg.name
          File.symlink dep_pkg.path, dest_pkg_dep_dir
        else
          Log.info "copying dependency", dep_pkg.name
          FileUtils.cp_r dep_pkg.path, dest_pkg_dep_dir
        end
      end
      Log.info "dependency added", dep_pkg.name
      yield dep_pkg
    end
  end

  def simulate_deps(deps : Set(Pkg), io)
    if !deps.empty?
      io << "\ndeps: "
      start = true
      deps.each do |dep_pkg|
        if start
          start = false
        else
          io << ", "
        end
        io << dep_pkg.name
      end
    end
    io << '\n'
  end
end
