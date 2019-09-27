require "../prefix_helper"
require "../../src/prefix"

def spec_with_app(&block)
  DPPM::Log.output = DPPM::Log.error = File.open File::NULL, "w"
  spec_with_prefix do |prefix|
    pkg = prefix.new_pkg TEST_APP_PACKAGE_NAME
    app = pkg.new_app TEST_APP_PACKAGE_NAME
    app.add confirmation: false { }
    begin
      yield app
    ensure
      app.delete confirmation: false { }
    end
  end
end

describe DPPM::Prefix::App do
  it "exists" do
    spec_with_app do |app|
      app.exists?.should eq app
    end
  end

  spec_with_app do |app|
    it "has libraries" do
      app.libs.each &.package.should eq TEST_LIB_PACKAGE_NAME
    end

    describe "get config" do
      it "from the app" do
        app.get_config("port").to_s.to_i.should be_a Int32
      end

      it "from the app which is in a lib config" do
        app.get_config("host").should be_a String
      end

      it "raises config key on missing key" do
        expect_raises(DPPM::Prefix::App::ConfigKeyError) do
          app.get_config "does not exist"
        end
      end
    end
  end

  describe "del config" do
    spec_with_app do |app|
      it "from the app" do
        app.del_config("port")
        app.get_config("port").should be_nil
      end

      it "from the app which is in a lib config" do
        app.del_config("host")
        app.get_config("host").should be_nil
      end
    end
  end

  describe "set config" do
    spec_with_app do |app|
      it "from the app" do
        app.set_config("port", "123").should eq 123
        app.get_config("port").to_s.to_i.should eq 123
      end

      it "from the app which is in a lib config" do
        app.set_config("host", "local").should eq "local"
        app.get_config("host").should eq "local"
      end
    end
  end
end
