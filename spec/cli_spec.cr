require "./spec_helper"
require "../src/cli"
require "file_utils"

def install_dppm(prefix : String)
  DPPM::CLI.install_dppm(
    no_confirm: true,
    config: DPPM_CONFIG_FILE,
    prefix: prefix,
    group: DPPM::Prefix.default_group,
    source_name: DPPM::Prefix.default_source_name,
    source_path: nil
  )
end

describe DPPM::CLI do
  it "installs DPPM" do
    prefix = spec_root_prefix
    begin
      install_dppm prefix
    ensure
      FileUtils.rm_rf prefix
    end
  end

  it "uninstalls DPPM" do
    prefix = spec_root_prefix
    begin
      install_dppm prefix

      DPPM::CLI.uninstall_dppm(
        no_confirm: true,
        config: DPPM_CONFIG_FILE,
        prefix: prefix,
        group: DPPM::Prefix.default_group,
        source_name: DPPM::Prefix.default_source_name,
        source_path: nil
      )
    ensure
      FileUtils.rm_rf prefix
    end
  end
end
