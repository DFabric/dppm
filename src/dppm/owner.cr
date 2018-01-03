module Owner
  extend self

  def to_id(id, id_type)
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

  def from_id(id, id_type)
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

  def new_user_group(name)
    passwd = File.read "/etc/passwd"
    group = File.read "/etc/group"
    # "/etc/passwd", name + ":x:" + id + ':' + id + "::/:/sbin/nologin"
    # "/etc/group",  name + ":x:" + id + ':'
  end
end
