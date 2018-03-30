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
  service_vars = {
    "directory" => path,
    "user"      => "1000",
    "group"     => "1000",
  }

  {% for sysinit in %w(OpenRC Systemd) %}
    describe {{sysinit}} do
      service = Service::{{sysinit.id}}::Config.new

      it "creates a service" do
        Service::{{sysinit.id}}.create(YAML.parse(File.read "./samples/package/pkg.yml"), vars) { |a, b, c| nil }
      end

      it "parses the service" do
        service = Service::{{sysinit.id}}::Config.new(path + "etc/init/" + {{sysinit.downcase}}, file: true)
      end

      it "checks values of sections" do
        service_vars.each do |key, value|
          value.should eq(service.get key)
        end
      end

      it "verifies the builded service" do
        File.read(path + "etc/init/" + {{sysinit.downcase}}).should eq service.build
      end

      it "adds environment variables" do
        service.env_set "TEST", "some_test"
        service.env_set "ENV", "production"
      end

      it "checks value of environment variables" do
        service.env_get("TEST").should eq "some_test"
        service.env_get("ENV").should eq "production"
      end
    end
  {% end %}

  FileUtils.rm_r path
end
