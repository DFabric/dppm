require "../spec_helper"
require "../../src/manager"

describe Manager::Source::Cache do
  it "downloads with cli using the config.ini mirror" do
    Dir.mkdir TEMP_DPPM_PREFIX
    begin
      Manager::Source::Cache.cli "#{__DIR__}/../../config.ini", nil, nil, TEMP_DPPM_PREFIX, true
      Dir.new(TEMP_DPPM_PREFIX).children.should eq ["app", "pkg", "src"]
      Dir[Path.new(TEMP_DPPM_PREFIX).src + "/*/pkg.yml"].empty?.should be_false
    ensure
      FileUtils.rm_r TEMP_DPPM_PREFIX
    end
  end
end
