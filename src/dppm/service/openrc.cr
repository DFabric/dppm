module Service::OpenRC
  extend self
  include Service

  def create(pkg, vars, &log : String, String, String -> Nil)
    # Convert back hashes to service files
    File.write vars["pkgdir"] + "etc/init/openrc", creation("OpenRC", pkg, vars, &log).build
  end

  def writable?
    File.writable? "/etc/init.d/"
  end

  def name
    "OpenRC"
  end

  def version
    Exec.new("/sbin/openrc", ["-V"]).out.match(/([0-9]+\.[0-9]+\.[0-9]+)/).not_nil![1]
  end

  def log
    # "/var/log/" + service + ".log"
  end
end
