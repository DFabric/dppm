require "../src/prefix"
require "./spec_helper"

def spec_with_prefix(&block)
  spec_with_tempdir do |tempdir|
    prefix = DPPM::Prefix.new path: tempdir, source_path: SAMPLES_DIR
    prefix.create
    prefix.update
    FileUtils.mkdir_p (prefix.app / "dppm").to_s
    begin
      yield prefix
    ensure
      prefix.delete
    end
  end
end
