require "file_utils"

module Manager::Source::Cache
  extend self

  def latest?(source : String, src_path : String)
    if HTTPHelper.url? source
      # != File.info(src_prefix).modification_time.to_s("%Y%m%d").to_i
      HTTPHelper.get_string(source.gsub("tarball", "commits")) =~ /(?<=datetime=").*T[0-9][0-9]:/
      $0.starts_with? File.info(src_path).modification_time.to_utc.to_s("%Y-%m-%dT%H:")
    end
  end

  # Download a cache of package sources
  def update(prefix : Prefix, source : String, force : Bool = false)
    # Update cache if older than 2 days
    source_dir = prefix.src.rchop
    if force || !(File.symlink?(source_dir) || latest?(source, source_dir))
      if File.symlink? source_dir
        File.delete source_dir
      else
        FileUtils.rm_rf prefix.src
      end
      if HTTPHelper.url? source
        Log.info "downloading packages source", source
        file = prefix.path + '/' + File.basename source
        HTTPHelper.get_file source, file
        Host.exec "/bin/tar", {"zxf", file, "-C", prefix.path}
        File.delete file
        File.rename Dir[prefix.path + "/*packages-source*"][0], prefix.src
        Log.info "cache updated", prefix.src
      else
        FileUtils.mkdir_p prefix.path
        File.symlink File.real_path(source), source_dir
        Log.info "symlink added from `#{File.real_path(source)}`", source_dir
      end
    else
      Log.info "cache up-to-date", prefix.src
    end
  end

  def cli(config, source, prefix, no_confirm, **args)
    prefix = Prefix.new prefix, create: true
    if source
      update prefix, source, no_confirm
    else
      MainConfig.file = config
      update prefix, MainConfig.source, no_confirm
    end
  end
end
