require "./spec_helper"
require "../src/manager"

describe Manager do
  # it "converts an user name to an uid" do
  # ::System::Owner.to_uid("root").should eq 0
  # end
  describe "Source::Cache" do
    temp_prefix_dir = "./spec/temp_dppm_prefix"
    it "downloads with cli using the config.ini mirror" do
      begin
        Manager::Source::Cache.cli "./config.ini", nil, nil, temp_prefix_dir, true
        Dir.new(temp_prefix_dir).children.should eq ["app", "pkg", "src"]
        Dir[Path.new(temp_prefix_dir).src + "/*/pkg.yml"].empty?.should be_false
      ensure
        FileUtils.rm_r temp_prefix_dir
      end
    end
  end
end
