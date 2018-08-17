module Package::Cache
  extend self

  def latest_source?(pkgsrc, src)
    # != File.info(src).modification_time.to_s("%Y%m%d").to_i
    HTTPget.string(pkgsrc.gsub("tarball", "commits")) =~ /(?<=datetime=").*T[0-9][0-9]:/
    File.info(src).modification_time.to_s("%Y-%m-%dT%H:%M:") == $0
  end

  # Download a cache of package sources
  def update(pkgsrc, src, force = false)
    # Update cache if older than 2 days
    if force || !(File.exists?(src) || File.symlink?(src)) || latest_source?(pkgsrc, src)
      FileUtils.rm_r src if File.exists? src
      if Utils.is_http? pkgsrc
        HTTPget.file pkgsrc, src + ".tar.gz"
        tmp = File.dirname(src)
        Exec.new("/bin/tar", ["zxf", src + ".tar.gz", "-C", tmp]).out
        File.delete src + ".tar.gz"
        File.rename Dir[tmp + "/*packages-source*"][0], src
        Log.info "cache updated", src
      else
        File.symlink File.real_path(pkgsrc), src
        Log.info "symlink added from `#{File.real_path(pkgsrc)}`", src
      end
    else
      Log.info "cache up-to-date", src
    end
  end

  def cli(config, mirror, pkgsrc, prefix, no_confirm)
    src = ::Package::Path.new(prefix).src
    if pkgsrc
      update pkgsrc, src, no_confirm
    else
      update INI.parse(File.read config)["main"]["pkgsrc"], src, no_confirm
    end
  end
end
