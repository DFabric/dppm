module Service::OpenRC
  extend self
  include Service

  def system
    System
  end

  def config
    Config
  end

  def create(pkg, vars)
    sysinit_hash = creation Config.new(vars["pkgdir"] + "/etc/init/openrc", file: true), pkg, vars

    # Convert back hashes to service files
    File.write vars["pkgdir"] + "/etc/init/openrc", sysinit_hash.build
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
