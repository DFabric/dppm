require "./spec_helper"

describe Service do
  path = Dir.current + "/service_test/"
  vars = {
    "package" => "test",
    "pkgdir"  => path,
    "user"    => "1000",
    "group"   => "1000",
  }
  service = {
    "directory" => path,
    "user"      => "1000",
    "group"     => "1000",
  }

  it "creates OpenRC and systemd services" do
    library = path + "lib/library/bin"
    Dir.mkdir_p library
    Service.create(YAML.parse(File.read "./samples/package/pkg.yml"), vars) { |a, b, c| Nil }
  end

  it "checks values for OpenRC sections" do
    openrc = Service::OpenRC.parse(File.read path + "etc/init/openrc")
    service.each_key do |var|
      service[var].should eq(Service::OpenRC.get openrc, var)
    end
  end

  it "checks values for systemd sections" do
    systemd = Service::Systemd.parse(File.read path + "etc/init/systemd")
    service.each_key do |var|
      service[var].should eq(Service::Systemd.get systemd, var)
    end
  end

  FileUtils.rm_r path
end
