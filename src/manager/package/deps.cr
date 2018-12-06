require "semantic_compare"

struct Manager::Package::Deps
  @path : Path
  @pkgdir : String

  def initialize(@path, @pkgdir)
  end

  def resolve(pkg_file : PkgFile, dependencies = Hash(PkgFile, Array(String)).new) : Hash(PkgFile, Array(String))
    # No need to parse if the deps list is empty
    (pkgdeps = pkg_file.deps) || return dependencies

    pkgdeps.each_key do |dep|
      if !File.exists? @pkgdir + "/lib/#{dep}"
        Log.info "calculing dependency", dep
        dep_pkg_file = PkgFile.new @path.src + dep
        newvers = Array(String).new

        # If an array of versions is already provided by a dependency
        if dep_vers = dependencies[dep_pkg_file]?
          dep_vers.each do |ver|
            newvers << ver if SemanticCompare.expression ver, pkgdeps[dep]
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          dependencies[dep_pkg_file] = Array(String).new
          Version.all(::System::Host.kernel, ::System::Host.arch, dep_pkg_file.version).each do |ver|
            newvers << ver if ver && SemanticCompare.expression ver, pkgdeps[dep]
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{dep_pkg_file.package}`: the versions required by `#{pkgdeps[dep]}` don't match" if !newvers[0]?
        dependencies[dep_pkg_file] = newvers

        # Loops inside dependencies of dependencies
        dependencies = resolve(dep_pkg_file, dependencies) if dep_pkg_file.deps
      end
    end
    dependencies
  end

  def build(vars : Hash(String, String), deps : Hash(String, String), shared : Bool = true)
    Log.info "dependencies", "building"
    Dir.mkdir_p @pkgdir + "/lib"

    # Build each dependency
    deps.each do |dep, ver|
      dep_prefix_pkg = "#{@path.pkg}/#{dep}_#{ver}"
      dep_pkgdir_lib = "#{@pkgdir}/lib/#{dep}"
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
