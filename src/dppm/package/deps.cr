require "yaml"
require "semantic_compare"

struct Package::Deps
  @path : Package::Path

  def initialize(@path)
  end

  def get(pkg, pkgdir, allvers = Hash(String, Array(String)).new)
    # No need to parse if the deps list is empty
    if pkg_deps = pkg["deps"]?
      pkgdeps = pkg_deps.as_h
    else
      return allvers
    end

    pkgdeps.each_key do |dep|
      if !File.exists? pkgdir + "/lib/#{dep}"
        Log.info "calculing dependency", dep.to_s
        yaml = YAML.parse File.read "#{@path.src}/#{dep}/pkg.yml"
        newvers = Array(String).new

        # If an array of versions is already provided by a dependency
        if dep_vers = allvers[dep]?
          dep_vers.each do |ver|
            newvers << ver if SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          allvers[dep.to_s] = Array(String).new
          Version.get(Localhost.kernel, Localhost.arch, yaml["version"]).each do |ver|
            newvers << ver if ver && SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{pkg["package"]}`: the versions required by `#{pkgdeps[dep]}` don't match" if !newvers[0]?
        allvers[dep.to_s] = newvers

        # Loops inside dependencies of dependencies
        allvers = get(YAML.parse(File.read "#{@path.src}/#{dep}/pkg.yml"), pkgdir, allvers) if yaml["deps"]?
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
      dep_prefix_pkg = "#{@path.prefix}/pkg/#{dep}_#{ver}"
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
