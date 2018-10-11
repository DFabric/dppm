require "file_utils"

module Manager::Source::Cache
  extend self

  def latest?(source, src)
    if Utils.is_http? source
      # != File.info(src).modification_time.to_s("%Y%m%d").to_i
      HTTPget.string(source.gsub("tarball", "commits")) =~ /(?<=datetime=").*T[0-9][0-9]:/
      File.info(src).modification_time.to_s("%Y-%m-%dT%H:%M:") == $0
    end
  end

  # Download a cache of package sources
  def update(source, src, force = false)
    # Update cache if older than 2 days
    if force || !(File.exists?(src) || File.symlink?(src)) || latest?(source, src)
      FileUtils.rm_r src if File.exists? src
      if Utils.is_http? source
        HTTPget.file source, src + ".tar.gz"
        tmp = File.dirname(src)
        Exec.new("/bin/tar", ["zxf", src + ".tar.gz", "-C", tmp]).out
        File.delete src + ".tar.gz"
        File.rename Dir[tmp + "/*packages-source*"][0], src
        Log.info "cache updated", src
      else
        File.symlink File.real_path(source), src
        Log.info "symlink added from `#{File.real_path(source)}`", src
      end
    else
      Log.info "cache up-to-date", src
    end
  end

  def cli(config, mirror, source, prefix, no_confirm)
    src = Path.new(prefix, create: true).src
    if source
      update source, src, no_confirm
    else
      update INI.parse(File.read config)["main"]["source"], src, no_confirm
    end
  end
end
