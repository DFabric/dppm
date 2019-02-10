require "../spec_helper"
require "../../src/prefix"

module IntegrationSpec
  def create_prefix(prefix_path : String) : Prefix
    Prefix.new prefix_path, create: true
  end

  def test_prefix_app(prefix : Prefix, application : String)
    app = prefix.new_app application

    describe Prefix::App do
      it "has a created directory" do
        Dir.exists?(app.path).should be_true
      end

      it "has libraries" do
        app.libs.each &.pkg.package.should eq TEST_LIB_PACKAGE_NAME
      end

      describe "get config" do
        it "from the app" do
          app.get_config("port").to_s.to_i.should be_a Int32
        end

        it "from the app which is in a lib config" do
          app.get_config("host").should be_a String
        end
      end

      describe "del config" do
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
