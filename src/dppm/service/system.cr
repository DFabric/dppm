abstract struct Service::System
  def boot?
    File.exists? @boot
  end

  def exists?
    File.symlink? @file
  end

  def writable?
    File.writable? @file
  end

  def real_file
    File.real_path @file
  end

  def log_dir
    File.dirname(File.dirname(File.dirname(real_file))) + "/log/"
  end

  def boot(value : Bool)
    # nothing to do
    return value if value == boot?

    value ? File.symlink(@file, @boot) : File.delete(@boot)
  end
end
