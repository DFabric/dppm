module Manager::ListCLI
  extend self

  def all(prefix, config, mirror, source, no_confirm)
    root_prefix = Prefix.new prefix
    puts "applications:"
    root_prefix.app { |app| puts app }
    puts "\npackages:"
    root_prefix.pkg { |pkg| puts pkg }
    puts "\nsources:"
    root_prefix.src { |src| puts src }
  end

  {% for i in %w(app pkg src) %}
  def {{i.id}}(prefix, config, mirror, source, no_confirm)
    Prefix.new(prefix).{{i.id}} { |i| puts i }
  end
  {% end %}
end
