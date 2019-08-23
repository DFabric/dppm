require "random"

module DPPM::Utils
  extend self

  def ascii_alphanumeric_underscore?(string : String) : Bool
    string.each_char { |char| char.ascii_lowercase? || char.ascii_number? || char == '_' || return false }
    true
  end

  def ascii_alphanumeric_dash?(name : String) : Bool
    raise "A name must starts with `a-z` or `0-9`, not a dash  `-`: " + name if name.starts_with? '-'
    name.each_char do |char|
      char.ascii_lowercase? || char.ascii_number? || char == '-' || raise "A name contains other characters than `a-z`, `0-9` and `-`: " + name
    end
    true
  end

  def to_b(string : String) : Bool
    case string
    when "true"  then true
    when "false" then false
    else              raise "Can't convert to a boolean: " + string
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
end
