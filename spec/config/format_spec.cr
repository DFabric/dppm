require "spec"
require "../../src/config/format"

module Config::Format
  extend self

  def ext_to_array(string : String)
    self.to_array string
  end

  def ext_to_type(string : String, strict = false)
    self.to_type string, strict
  end
end

describe Config::Format do
  it "converts to an array" do
    Config::Format.ext_to_array(".a.b[1].some\\.key[0]").should eq ["", "a", "b", 1, "some.key", 0]
  end

  describe "String to_type" do
    it "converts a quoted string to an unquoted one" do
      Config::Format.ext_to_type("'string'", true).should eq "string"
    end
    it "returns the passed string" do
      Config::Format.ext_to_type("string", false).should eq "string"
    end
    it "converts to a `true` bool" do
      Config::Format.ext_to_type("true").should eq true
    end
    it "converts to a `false` bool" do
      Config::Format.ext_to_type("false").should eq false
    end
    it "converts to an empty hash" do
      Config::Format.ext_to_type("{}").should eq Hash(String, String).new
    end
    it "converts to an empty array" do
      Config::Format.ext_to_type("[]").should eq Array(String).new
    end
    it "converts to an Int64" do
      Config::Format.ext_to_type("72").should eq 72
    end
    it "converts to a Float64" do
      Config::Format.ext_to_type("1.3").should eq 1.3
    end
  end
end
