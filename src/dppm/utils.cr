class String
  def ascii_alphanumeric_underscore?
    each_char { |char| char.ascii_lowercase? || char.ascii_number? || char == '_' || return false }
    true
  end
end

module Utils
  extend self

  def is_http?(link) : Bool
    link.starts_with?("http://") || link.starts_with?("https://")
  end

  def to_b(string)
    case string
    when "true"  then true
    when "false" then false
    else
      raise "can't convert to a boolean: " + string
    end
  end

  def to_array(string)
    string.split(/(?<!\\)\./).map &.gsub "\\.", '.'
  end

  def to_type(string : String, strict = false)
    case string
    when "true"  then true
    when "false" then false
    when "nil"   then nil
    when "{}"    then Hash(String, String).new
    when "[]"    then Array(String).new
    else
      if string.starts_with?('"') && string.ends_with?('"')
        string[1..-2]
      elsif string.to_i64?
        string.to_i64?
      elsif string.to_f64?
        string.to_f64?
      elsif strict
        raise "can't convert to a type: " + string
      else
        string
      end
    end
  end

  def chmod_r(path, mode : Int, follow_symlinks = false)
    File.chmod path, mode
    if (follow_symlinks || !File.symlink? path) && Dir.exists? path
      Dir.each_child path do |entry|
        src = File.join path, entry
        File.chmod src, mode
        chmod_r src, mode
      end
    end
  end

  def chown_r(path, uid : Int? = -1, gid : Int = -1, follow_symlinks = false)
    File.chown path, uid, gid, follow_symlinks
    if (follow_symlinks || !File.symlink? path) && Dir.exists? path
      Dir.each_child path do |entry|
        src = File.join path, entry
        File.chown src, uid, gid, follow_symlinks
        chown_r src, uid, gid, follow_symlinks
      end
    end
  end
  
  
  def gen_name(package)
    package + '_' + UUID.random.to_s.split('-').last
  end
end
