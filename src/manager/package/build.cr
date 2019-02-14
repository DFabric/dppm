struct Manager::Package::Build
  getter pkg : Prefix::Pkg,
    deps : Set(Prefix::Pkg) = Set(Prefix::Pkg).new,
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
    end
    # keep the latest ones for each dependency
    Log.info "calculing package dependencies", @pkg.name
    @pkg.src.resolve_deps.each do |dep_name, versions|
      version = if versions.includes?(latest = prefix.new_src(dep_name).pkg_file.version_from_tag "latest")
                  latest
                else
                  versions[0].to_s
                end
      @deps << pkg.prefix.new_pkg dep_name, version
    end
    @vars["prefix"] = prefix.path
    @vars["version"] = @pkg.version
    @vars["package"] = @pkg.package
    @vars["basedir"] = @pkg.path
    @vars["arch_alias"] = @arch_alias
    if env = @pkg.pkg_file.env
      @vars.merge! env
    end
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
      @deps.each do |dep_pkg|
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

  def install_deps(dest_pkg : Prefix::Pkg | Prefix::App, vars : Hash(String, String), shared : Bool = true, &block)
    Log.info "dependencies", "building"
    Dir.mkdir_p dest_pkg.libs_dir

    # Build each dependency
    @deps.each do |dep_pkg|
      dest_pkg_dep_dir = dest_pkg.libs_dir + dep_pkg.package
      if !Dir.exists? dep_pkg.path
        Log.info "building dependency", dep_pkg.path
        Package::Build.new(
          vars: vars,
          prefix: dest_pkg.prefix,
          package: dep_pkg.package,
          version: dep_pkg.version).run
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

  def run
    if File.exists? @pkg.path
      Log.info "package already present", @pkg.path
      return self
    end

    # Copy the sources to the @pkg.name directory to build
    FileUtils.cp_r(@pkg.src.path, @pkg.path)

    # Build dependencies
    install_deps(@pkg, @vars.dup) { }

    @pkg.build @vars
    Log.info "build completed", @pkg.path
    self
  rescue ex
    FileUtils.rm_rf @pkg.path
    raise Exception.new "build failed - package deleted: #{@pkg.path}:\n#{ex}", ex
  end
end
