abstract class Config::Format
  def get(path : String)
    get Utils.to_array(path)
  end

  def set(path : String, value)
    set Utils.to_array(path), value
  end

  def del(path : String)
    del Utils.to_array(path)
  end
end
