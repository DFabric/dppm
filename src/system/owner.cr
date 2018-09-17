require "file_utils"

module System::Owner
  @@nologin = Process.find_executable("nologin") || "/bin/false"
  extend self

  def current_uid_gid
    file = "/tmp/#{UUID.random}"
    File.touch file
    info = File.info file
    uid, gid = info.owner, info.group
    File.delete file
    {uid, gid}
  end

  def root? : Bool
    File.writable? "/"
  end

  private def get_id(name, file : String) : Int32
    if int = name.to_i?
      int.to_i
    else
      File.read_lines(file).each do |line|
        return $1.to_i if line =~ /#{name}:x:(.*?):/
      end
      raise "name not found in `#{file}`: #{name}"
    end
  end

  def to_uid(user) : Int32
    get_id user, "/etc/passwd"
  end

  def to_gid(group) : Int32
    get_id group, "/etc/group"
  end

  private def get_name(id, file : String) : String
    if id.is_a? Int || id.to_i?
      File.read_lines(file).each do |line|
        return $1 if line =~ /(.*):x:(#{id}):/
      end
      raise "ID not found in `#{file}`: #{id}"
    else
      id.to_s
    end
  end

  def to_user(uid) : String
    get_name uid, "/etc/passwd"
  end

  def to_group(gid) : String
    get_name gid, "/etc/group"
  end

  def all_gids
    a = Array(Int32).new
    File.read("/etc/group").each_line do |line|
      a << line.split(':')[2].to_i
    end
    a
  end

  def all_uids
    a = Array(Int32).new
    File.read("/etc/passwd").each_line do |line|
      a << line.split(':', 5)[2].to_i
    end
    a
  end

  def available_id
    id = 1000
    uids = all_uids
    gids = all_gids
    (id..65535).each do |id|
      return id unless uids.includes?(id) || gids.includes?(id)
    end
    raise "the limit of 65535 for id numbers is reached, no ids available"
  end

  def add_user(id, name, description, shell = @@nologin)
    File.open "/etc/passwd", "a", &.puts "#{name}:x:#{id}:#{id}:#{description}:/:#{@@nologin}"
  end

  def add_group(id, name)
    File.open "/etc/group", "a", &.puts "#{name}:x:#{id}:"
  end

  def del(name, file)
    File.write(file, String.build do |str|
      File.read(file).each_line do |line|
        str.puts line if !line.starts_with? name
      end
    end)
  end

  def del_user(name)
    del name, "/etc/passwd"
    Log.info "user deleted", name
  end

  def del_group(name)
    del name, "/etc/group"
    Log.info "group deleted", name
  end
end
