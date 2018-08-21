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

  def name
    "OpenRC"
  end

  def version
    Exec.new("/sbin/openrc", ["-V"]).out =~ /([0-9]+\.[0-9]+\.[0-9]+)/
    $1.to_i
  rescue ex
    raise "can't retrieve the OpenRC version #{ex}"
  end
end
