module Config::Format
  def get(path : String)
    get to_array(path)
  end

  def set(path : String, value)
    set to_array(path), value
  end

  def del(path : String)
    del to_array(path)
  end

  private def to_array(string : String) : Array(String | Int32)
    array = Array(String | Int32).new
    buffer = IO::Memory.new
    reader = Char::Reader.new string

    while reader.has_next?
      case char = reader.current_char
      when '\\' then buffer << reader.next_char
      when '.'
        array << buffer.to_s
        buffer.clear
      when '['
        array << buffer.to_s
        buffer.clear
      when ']'
        reader.next_char if reader.has_next? && reader.peek_next_char == '.'
        array << buffer.to_s.to_i
        buffer.clear
      else
        buffer << char
      end
      reader.next_char
    end
    array << buffer.to_s if !buffer.empty?

    array
  end

  private def to_type(string : String, strict : Bool = false) : Array(String) | Bool | Float64 | Hash(String, String) | Int64 | String | Nil
    case string
    when "true"  then true
    when "false" then false
    when "nil"   then nil
    when "{}"    then Hash(String, String).new
    when "[]"    then Array(String).new
    else
      if str = string.lchop?('\'').try &.rchop?('\'')
        str
      elsif int = string.to_i64?
        int
      elsif float = string.to_f64?
        float
      elsif strict
        raise "Can't convert to a type: " + string
      else
        string
      end
    end
  end
end
