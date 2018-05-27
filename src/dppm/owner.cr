require "file_utils"
require "uuid"

module Owner
  extend self

  def to_id(id, id_type) : Int32
    file = case id_type
           when "uid" then "/etc/passwd"
           when "gid" then "/etc/group"
           else            raise "only uid or gid can be used"
           end
    if id.is_a? Int || id.to_i?
      id.to_i
    else
      File.read_lines(file).each do |line|
        return $1.to_i if line =~ /#{id}:x:(.*?):/
      end
      raise id_type + " not found: " + id
    end
  end

  def from_id(id, id_type) : String
    file = case id_type
           when "uid" then "/etc/passwd"
           when "gid" then "/etc/group"
           else            raise "only uid or gid can be used"
           end
    if id.is_a? Int || id.to_i?
      File.read_lines(file).each do |line|
        return $1 if line =~ /(.*):x:(#{id}):/
      end
      raise id_type + " not found: #{id}"
    else
      id.to_s
    end
  end

  def all_groups
    a = Array(Int32).new
    File.read("/etc/group").each_line do |line|
      a << line.split(':')[2].to_i
    end
    a
  end

  def all_users
    a = Array(Int32).new
    File.read("/etc/passwd").each_line do |line|
      a << line.split(':', 5)[2].to_i
    end
    a
  end

  def available_id
    id = 1000
    users = all_users
    groups = all_groups
    while all_users.includes?(id)
      id += 1
    end
    id
  end

  def add(name, description)
    id = available_id
    File.open "/etc/passwd", "a", &.puts "#{name}:x:#{id}:#{id}:#{description}:/:/bin/false"
    File.open "/etc/group", "a", &.puts "#{name}:x:#{id}:"
  end

  def del(name, file)
    data = ""
    File.read(file).each_line do |line|
      data += line + '\n' if !line.starts_with? name
    end
    File.write file, data
  end

  def del_all(name)
    del name, "/etc/passwd"
    del name, "/etc/group"
  end
end
