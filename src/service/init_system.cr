module Service::InitSystem
  getter name : String,
    file : String,
    boot_file : String

  def config_tap(&block : Config -> Config)
    @config = yield config
  end

  def type : String
    self.class.type
  end

  def boot? : Bool
    File.exists? @boot_file
  end

  def exists? : Bool
    File.symlink?(@file) || File.exists?(@file)
  end

  def writable? : Bool
    File.writable? @file
  end

  def creatable? : Bool
    File.writable? File.dirname(@file)
  end

  def boot(value : Bool) : Bool
    case value
    when boot? # nothing to do
    when true  then File.symlink @file, @boot_file
    when false then File.delete boot_file
    end
    value
  end

  def real_file : String
    File.real_path file
  end

  private def delete_internal
    stop if run?
    boot false if boot?
    File.delete @file if exists?
  end

  def check_delete
    if !writable?
      raise "root execution needed for system service deletion: " + name
    elsif !exists?
      raise "service doesn't exist: " + name
    end
  end
end
