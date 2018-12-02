require "semantic_compare"

struct Manager::Package::Deps
  @path : Path

  def initialize(@path)
  end

  def get(pkg_file : PkgFile, pkgdir, allvers = Hash(String, Array(String)).new)
    # No need to parse if the deps list is empty
    (pkgdeps = pkg_file.deps) || return allvers

    pkgdeps.each_key do |dep|
      if !File.exists? pkgdir + "/lib/#{dep}"
        Log.info "calculing dependency", dep.to_s
        deps_pkg_file = PkgFile.new "#{@path.src}/#{dep}"
        newvers = Array(String).new

        # If an array of versions is already provided by a dependency
        if dep_vers = allvers[dep]?
          dep_vers.each do |ver|
            newvers << ver if SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          allvers[dep.to_s] = Array(String).new
          Version.get(::System::Host.kernel, ::System::Host.arch, deps_pkg_file.version).each do |ver|
            newvers << ver if ver && SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{deps_pkg_file.package}`: the versions required by `#{pkgdeps[dep]}` don't match" if !newvers[0]?
        allvers[dep.to_s] = newvers

        # Loops inside dependencies of dependencies
        allvers = get(PkgFile.new(@path.src + dep), pkgdir, allvers) if deps_pkg_file.deps
      end
    end
    allvers
  end

  def build(vars : Hash(String, String), deps, shared = true)
    Log.info "dependencies", "building"
    pkgdir = vars["pkgdir"]
    Dir.mkdir_p pkgdir + "/lib"

    # Build each dependency
    deps.each do |dep, ver|
      dep_prefix_pkg = "#{@path.pkg}/#{dep}_#{ver}"
      dep_pkgdir_lib = "#{pkgdir}/lib/#{dep}"
      if !Dir.exists? dep_prefix_pkg
        Log.info "building dependency", dep_prefix_pkg
        Package::Build.new(vars.merge({"package" => dep,
                                       "version" => ver})).run
      end
      if !File.exists? dep_pkgdir_lib
        if shared
          Log.info "adding symlink to dependency", "#{dep}:#{ver}"
          File.symlink dep_prefix_pkg, dep_pkgdir_lib
        else
          Log.info "copying dependency", "#{dep}:#{ver}"
          FileUtils.cp_r dep_prefix_pkg, dep_pkgdir_lib
        end
      end
      Log.info "dependency added", "#{dep}:#{ver}"
    end
  end
end
