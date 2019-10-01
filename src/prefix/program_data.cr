require "./base"
require "./program_data_task"

module DPPM::Prefix::ProgramData
  include Base

  getter all_bin_paths : Array(Path) do
    paths = [app_bin_path]
    libs.each do |library|
      paths << library.bin_path
    end
    paths
  end

  # Path where application data is stored.
  getter data_path : Path { @path / "data" }

  # Application package path, where is the application executable.
  getter app_path : Path { @path / "app" }

  # Path of the application binary.
  getter app_bin_path : Path { app_path / "bin" }

  # Path of the web-sites files.
  getter site_path : Path { @path / "site" }

  # Libraries on which the application depend.
  getter libs : Array(Pkg) do
    libs = Array(Pkg).new
    return libs if !Dir.exists? libs_path.to_s

    Dir.each_child libs_path.to_s do |lib_package|
      lib_path = libs_path / lib_package
      lib_pkg = @prefix.new_pkg Path[File.real_path lib_path.to_s].basename
      app_config_file = nil
      conf_libs_path = (conf_path / lib_pkg.package).to_s
      if Dir.exists? conf_libs_path
        Dir.each_child conf_libs_path do |file|
          app_config_file = Path[conf_libs_path, file]
          lib_pkg.app_config = ::Config.read? app_config_file
        end
      end
      lib_pkg.app_config_file = app_config_file
      libs << lib_pkg
    end

    libs
  end

  # Return `self` if the root directory is available, else raise.
  def available!
    raise "Directory already exists: " + @path.to_s if exists?
    self
  end

  # Returns `self` if the root directory exists.
  def exists?
    self if File.exists? @path.to_s
  end

  # Install the package dependencies.
  def install_deps(deps : Set(Pkg), shared : Bool = true, &block)
    Logger.info "bulding dependencies", libs_path.to_s
    Dir.mkdir_p libs_path.to_s

    # Build each dependency
    deps.each do |dep_pkg|
      dest_pkg_dep_dir = (libs_path / dep_pkg.package).to_s
      if !Dir.exists? dep_pkg.path.to_s
        Logger.info "building dependency", dep_pkg.path.to_s
        dep_pkg.build
      end
      if !File.exists? dest_pkg_dep_dir
        if shared
          Logger.info "adding symlink to dependency", dep_pkg.name
          File.symlink dep_pkg.path.to_s, dest_pkg_dep_dir
        else
          Logger.info "copying dependency", dep_pkg.name
          FileUtils.cp_r dep_pkg.path.to_s, dest_pkg_dep_dir
        end
      end
      Logger.info "dependency added", dep_pkg.name
      yield dep_pkg
    end
  end

  # Operation summary before performing the task.
  private def simulate(vars : Hash(String, String), deps : Set(Pkg), task : String, confirmation : Bool, io : IO, &block) : Nil
    if confirmation
      io << "task: " << task
      vars.each do |var, value|
        io << '\n' << var << ": " << value
      end
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
      return if !yield
    else
      yield
    end
  end
end
