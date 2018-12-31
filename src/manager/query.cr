struct Manager::Query
  @any : CON::Any

  def initialize(@any : CON::Any)
  end

  def pkg(path : String) : CON::Any
    case path
    when "."
      @any
    else
      @any[Utils.to_array path]
    end
  end
end
