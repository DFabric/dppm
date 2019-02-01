require "random"

module Utils
  extend self

  def ascii_alphanumeric_underscore?(string : String) : Bool
    string.each_char { |char| char.ascii_lowercase? || char.ascii_number? || char == '_' || return false }
    true
  end

  def ascii_alphanumeric_dash?(name : String) : Bool
    raise "the name must starts with `a-z` or `0-9`, not a dash  `-`: " + name if name.starts_with? '-'
    name.each_char do |char|
      char.ascii_lowercase? || char.ascii_number? || char == '-' || raise "the name contains other characters than `a-z`, `0-9` and `-`: " + name
    end
    true
  end

  def to_b(string : String) : Bool
    case string
    when "true"  then true
    when "false" then false
    else              raise "can't convert to a boolean: " + string
    end
  end

  def to_array(string : String) : Array(String | Int32)
    array = Array(String | Int32).new
    escape = false
    current = IO::Memory.new
    reader = Char::Reader.new string
    while reader.has_next?
      case char = reader.current_char
      when '\\' then current << reader.next_char
      when '.'
        if !array[-1]?.is_a? Int32
          array << current.to_s
          current.clear
        end
      when '['
        if !current.empty?
          array << current.to_s
          current.clear
        end
      when ']'
        array << current.to_s.to_i
        current.clear
      else
        current << char
      end
      reader.next_char
    end
    array << current.to_s if !current.empty?

    array
  end

  def to_type(string : String, strict = false) : Array(String) | Bool | Float64 | Hash(String, String) | Int64 | String | Nil
    case string
    when "true"  then true
    when "false" then false
    when "nil"   then nil
    when "{}"    then Hash(String, String).new
    when "[]"    then Array(String).new
    else
      if string.starts_with?('\'') && string.ends_with?('\'')
        string[1..-2]
      elsif int = string.to_i64?
        int
      elsif float = string.to_f64?
        float
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

  def gen_password : String
    Random::Secure.urlsafe_base64
  end
end
