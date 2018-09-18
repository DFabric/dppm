require "./cmd"
require "./httpget"
require "./manager/*"
require "./path"

module Manager
  def self.pkg_exists?(dir)
    raise "doesn't exist: #{dir}/pkg.yml" if !File.exists? dir + "/pkg.yml"
  end
end
