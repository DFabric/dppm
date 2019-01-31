require "semantic_compare"

struct Manager::Package::Deps
  @prefix : Prefix
  @libs_dir : String

  def initialize(@prefix : Prefix, @libs_dir : String)
  end

  def resolve(pkg_file : Prefix::PkgFile, dependencies = Hash(Prefix::Src, Array(SemanticVersion)).new) : Hash(Prefix::Src, Array(SemanticVersion))
    # No need to parse if the deps list is empty
    (pkgdeps = pkg_file.deps) || return dependencies

    pkgdeps.each_key do |dep|
      if !File.exists? @libs_dir + dep
        Log.info "calculing dependency", dep
        dep_src = @prefix.new_src dep
        newvers = Array(SemanticVersion).new

        # If an array of versions is already provided by a dependency
        if dep_vers = dependencies[dep_src.pkg_file]?
          dep_vers.each do |semantic_version|
            newvers << semantic_version if SemanticCompare.expression semantic_version, pkgdeps[dep]
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          dependencies[dep_src] = Array(SemanticVersion).new
          dep_src.pkg_file.each_version do |ver|
            semantic_version = SemanticVersion.parse ver
            newvers << semantic_version if SemanticCompare.expression semantic_version, pkgdeps[dep]
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{dep_src.pkg_file.package}`: the versions required by `#{pkgdeps[dep]}` don't match" if !newvers[0]?
        dependencies[dep_src] = newvers

        # Loops inside dependencies of dependencies
        dependencies = resolve(dep_src.pkg_file, dependencies) if dep_src.pkg_file.deps
      end
    end
    dependencies
  end

  def build(vars : Hash(String, String), deps : Hash(String, String), shared : Bool = true, &block)
    Log.info "dependencies", "building"
    Dir.mkdir_p @libs_dir

    # Build each dependency
    deps.each do |dep_name, ver|
      dep_pkg = @prefix.new_pkg dep_name, ver
      dep_pkgdir_lib = @libs_dir + dep_name
      pretty_name = dep_name + ':' + ver
      if !Dir.exists? dep_pkg.path
        Log.info "building dependency", dep_pkg.path
        Package::Build.new(
          vars: vars,
          prefix: @prefix,
          package: dep_name,
          version: ver).run
      end
      if !File.exists? dep_pkgdir_lib
        if shared
          Log.info "adding symlink to dependency", pretty_name
          File.symlink dep_pkg.path, dep_pkgdir_lib
        else
          Log.info "copying dependency", pretty_name
          FileUtils.cp_r dep_pkg.path, dep_pkgdir_lib
        end
      end
      Log.info "dependency added", pretty_name
      yield dep_pkg
    end
  end
end
