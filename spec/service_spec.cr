require "./spec_helper"

describe Service do
  path = Dir.current + "/service_test/"
  library = path + "lib/library/bin"
  Dir.mkdir_p library

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


  describe "OpenRC" do
    openrc = Service::OpenRC::Config.new

    it "creates a service" do
      Service::OpenRC.create(YAML.parse(File.read "./samples/package/pkg.yml"), vars) { |a, b, c| nil }
    end

    it "parses the service" do
      openrc = Service::OpenRC::Config.new(path + "etc/init/openrc", file: true)
    end

    it "checks values of sections" do
      service.each_key do |var|
        service[var].should eq(openrc.get var)
      end
    end

    it "verifies the builded service" do
      File.read(path + "etc/init/openrc").should eq openrc.build
    end
  end

  describe "systemd" do
    systemd = Service::Systemd::Config.new

    it "creates a service" do
      Service::Systemd.create(YAML.parse(File.read "./samples/package/pkg.yml"), vars) { |a, b, c| nil }
    end

    it "parses the service" do
      systemd = Service::Systemd::Config.new(path + "etc/init/systemd", file: true)
    end

    it "checks values of sections" do
      service.each_key do |var|
        service[var].should eq(systemd.get var)
      end
    end

    it "verifies the builded service" do
      File.read(path + "etc/init/systemd").should eq systemd.build
    end
  end

  FileUtils.rm_r path
end
