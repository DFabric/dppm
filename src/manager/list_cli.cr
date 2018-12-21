module Manager::ListCLI
  extend self

  def all(prefix, config, mirror, source, no_confirm)
    root_prefix = Prefix.new prefix
    puts "applications:"
    root_prefix.each_app { |app| puts app }
    puts "\npackages:"
    root_prefix.each_pkg { |pkg| puts pkg }
    puts "\nsources:"
    root_prefix.each_src { |src| puts src }
  end

  {% for dir in %w(app pkg src) %}
  def {{dir.id}}(prefix, config, mirror, source, no_confirm)
    Prefix.new(prefix).each_{{dir.id}} { |el| puts el }
  end
  {% end %}
end
