module DPPM::CLI::List
  extend self

  def all(prefix, source_name, source_path, group = nil)
    root_prefix = Prefix.new prefix, group: group || Prefix.default_group, source_name: source_name, source_path: source_path
    Logger.output.puts "applications:"
    root_prefix.each_app { |app| Logger.output.puts app.name }
    Logger.output.puts "\npackages:"
    root_prefix.each_pkg { |pkg| Logger.output.puts pkg.name }
    Logger.output.puts "\nsources:"
    root_prefix.each_src { |src| Logger.output.puts src.name }
  end

  {% for dir in %w(app pkg src) %}
  def {{dir.id}}(prefix)
    Prefix.new(prefix).each_{{dir.id}} { |el| Logger.output.puts el.name }
  end
  {% end %}
end
