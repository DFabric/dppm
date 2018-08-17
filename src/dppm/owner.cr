require "file_utils"

module Owner
  extend self

  def current_uid_gid
    file_name = "/tmp/#{UUID.random}"
    File.touch file_name
    file = File.new file_name
    uid, gid = file.info.owner, file.info.group
    File.delete file.path
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
    while uids.includes?(id) || gids.includes?(id)
      id += 1
    end
    id
  end

  def add_user(id, name, description)
    File.open "/etc/passwd", "a", &.puts "#{name}:x:#{id}:#{id}:#{description}:/:/bin/false"
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

  def generated?(name, package)
    name.starts_with?(package + '_') && name.ascii_alphanumeric_underscore?
  end
end
