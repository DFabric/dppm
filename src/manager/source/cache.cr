require "file_utils"

module Manager::Source::Cache
  extend self

  def latest?(source : String, src_path : String)
    if Utils.is_http? source
      # != File.info(src_path).modification_time.to_s("%Y%m%d").to_i
      HTTPget.string(source.gsub("tarball", "commits")) =~ /(?<=datetime=").*T[0-9][0-9]:/
      File.info(src_path).modification_time.to_s("%Y-%m-%dT%H:%M:") == $0
    end
  end

  # Download a cache of package sources
  def update(source : String, prefix : String, force : Bool = false)
    path = Path.new prefix, create: true
    # Update cache if older than 2 days
    if force || !(File.exists?(path.src) || File.symlink?(path.src.rchop)) || latest?(source, path.src)
      if File.symlink? path.src.rchop
        File.delete path.src.rchop
      else
        FileUtils.rm_rf path.src
      end
      if Utils.is_http? source
        file = path.prefix + '/' + File.basename source
        HTTPget.file source, file
        Manager.exec "/bin/tar", {"zxf", file, "-C", path.prefix}
        File.delete file
        File.rename Dir[path.prefix + "/*packages-source*"][0], path.src
        Log.info "cache updated", path.src
      else
        FileUtils.mkdir_p path.prefix
        File.symlink File.real_path(source), path.src.rchop
        Log.info "symlink added from `#{File.real_path(source)}`", path.src.rchop
      end
    else
      Log.info "cache up-to-date", path.src
    end
  end

  def cli(config, mirror, source, prefix, no_confirm)
    if source
      update source, prefix, no_confirm
    else
      main_config = MainConfig.new config, mirror, nil
      update main_config.source, prefix, no_confirm
    end
  end
end
