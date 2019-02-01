struct Manager::Package::Build
  getter pkg : Prefix::Pkg,
    exists : Bool = false,
    deps : Hash(String, String) = Hash(String, String).new,
    vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars : Hash(String, String), prefix : Prefix, package : String, version : String?)
    @pkg = Prefix::Pkg.create prefix, package, version, @vars["tag"]?

    @arch_alias = if (aliases = @pkg.pkg_file.aliases) && (version_alias = aliases[Host.arch]?)
                    version_alias
                  else
                    Host.arch
                  end

    if File.exists? @pkg.path
      Log.info "already present", @pkg.path
      @exists = true
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @pkg.name
    Deps.new(prefix, @pkg.libs_dir).resolve(@pkg.pkg_file).each do |dep_src, versions|
      @deps[dep_src.name] = if versions.includes?(latest = dep_src.pkg_file.version_from_tag "latest")
                              latest
                            else
                              versions[0].to_s
                            end
    end
    @vars["prefix"] = prefix.path
    @vars["version"] = @pkg.version
    @vars["package"] = @pkg.package
    @vars["basedir"] = @pkg.path
    @vars["arch_alias"] = @arch_alias
  end

  def simulate(io = Log.output)
    io << "task: build"
    @vars.each do |var, value|
      io << '\n' << var << ": " << value
    end
    simulate_deps io
  end

  def simulate_deps(io)
    if !@deps.empty?
      io << "\ndeps: "
      start = true
      @deps.each do |dep, ver|
        if start
          start = false
        else
          io << ", "
        end
        io << dep << ':' << ver
      end
    end
  end

  def run
    if @exists
      Log.info "package already present", @pkg.path
      return self
    end

    # Copy the sources to the @pkg.name directory to build
    FileUtils.cp_r(@pkg.src.path, @pkg.path)

    # Build dependencies
    Deps.new(@pkg.prefix, @pkg.libs_dir).build @vars.dup, @deps { }

    if (tasks = @pkg.pkg_file.tasks) && (build_task = tasks["build"]?)
      Log.info "building", @pkg.name
      Dir.cd(@pkg.path) { Cmd.new(@vars.dup).run build_task }
      # Standard package build
    else
      Log.info "standard building", @pkg.name

      working_directory = if @pkg.pkg_file.type.app?
                            Dir.mkdir @pkg.app_path
                            @pkg.app_path
                          else
                            @pkg.path
                          end
      Dir.cd working_directory do
        package_full_name = "#{@pkg.package}-static_#{@pkg.version}_#{Host.kernel}_#{Host.arch}"
        package_archive = package_full_name + ".tar.xz"
        package_mirror = @vars["mirror"] + '/' + package_archive
        Log.info "downloading", package_mirror
        HTTPHelper.get_file package_mirror
        Log.info "extracting", package_mirror
        Manager.exec "/bin/tar", {"Jxf", package_archive}

        # Move out files from the archive folder
        Dir.cd package_full_name do
          move "./"
        end
        FileUtils.rm_r({package_archive, package_full_name})
      end
    end
    FileUtils.rm_rf @pkg.libs_dir
    Log.info "build completed", @pkg.path
    self
  rescue ex
    FileUtils.rm_rf @pkg.path
    raise Exception.new "build failed - package deleted: #{@pkg.path}:\n#{ex}", ex
  end

  private def move(path)
    Dir.each_child(path) do |entry|
      src = path + entry
      dest = '.' + src
      if Dir.exists? dest
        move src + '/'
      else
        File.rename src, dest
      end
    end
  end
end
