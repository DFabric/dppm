struct Manager::Package::Build
  getter src : Prefix::Src,
    pkg : Prefix::Pkg,
    exists = false,
    deps = Hash(String, String).new,
    vars : Hash(String, String)
  @arch_alias : String

  def initialize(@vars : Hash(String, String), prefix : Prefix)
    parsed_package = @vars["package"].split(':')

    @src = Prefix::Src.new prefix, parsed_package[0]
    version = @vars["version"] = getversion parsed_package[1]?
    @pkg = @src.new_pkg(@src.name + '_' + version)

    @vars["package"] = @pkg.package
    @vars["name"] = @pkg.name
    @vars["basedir"] = @pkg.path
    @arch_alias = @vars["arch_alias"] = if (aliases = @src.pkg_file.aliases) && (version_alias = aliases[Host.arch]?)
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
    Deps.new(prefix, @pkg.libs_dir).resolve(@src.pkg_file).each do |dep_pkg_file, versions|
      @deps[dep_pkg_file.package] = if versions.includes?(latest = dep_pkg_file.version_from_tag "latest")
                                      latest
                                    else
                                      versions[0].to_s
                                    end
    end
  end

  private def getversion(package_tag : String? = nil) : String
    if ver = @vars["version"]?
    elsif tag = @vars["tag"]?
    elsif tag = package_tag
      ver = tag if tag =~ /^([0-9]+\.[0-9]+\.[0-9]+)/
      # Set a default tag if not set
    else
      tag = "latest"
    end
    if ver
      # Check if the version number is available
      @src.pkg_file.each_version do |version|
        return ver if version == ver
      end
      raise "not available version number: " + ver
    elsif tag
      @src.pkg_file.version_from_tag tag
    else
      raise "fail to get a version"
    end
  rescue ex
    raise "can't obtain a version: #{ex}"
  end

  def simulate
    String.build do |str|
      @vars.each { |k, v| str << "\n#{k}: #{v}" }
      if !@deps.empty?
        str << "\ndeps: "
        @deps.map { |k, v| k + ':' + v }.join(", ", str)
      end
    end
  end

  def run
    raise "package already present: " + @pkg.path if @exists

    # Copy the sources to the @pkg.name directory to build
    FileUtils.cp_r(@src.path, @pkg.path)

    # Build dependencies
    Deps.new(@pkg.prefix, @pkg.libs_dir).build @vars.dup, @deps

    if (tasks = @src.pkg_file.tasks) && (build_task = tasks["build"]?)
      Log.info "building", @pkg.name
      Dir.cd(@pkg.path) { Cmd.new(@vars.dup).run build_task.as_a }
      # Standard package build
    else
      Log.info "standard building", @pkg.name

      working_directory = if @src.pkg_file.type.app?
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
        HTTPget.file package_mirror
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
    raise "build failed - package deleted: #{@pkg.path}:\n#{ex}"
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
