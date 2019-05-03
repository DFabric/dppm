module DPPM
  extend self

  def build_date : String
    {{ `date --utc -Iminutes`.stringify.chomp }}
  end

  def build_commit : String
    {{ `git rev-parse --short HEAD`.stringify.chomp }}
  end

  def version : String
    {{ `date --utc +"%Y.%m.%d"`.stringify.chomp }}
  end

  # Default prefix for a DPPM installation
  class_getter default_prefix : String do
    if (current_dir = Dir.current).ends_with? "/app/dppm"
      File.dirname(File.dirname(File.dirname(File.dirname(File.dirname current_dir))))
    elsif File.exists? "/usr/local/bin/dppm"
      File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(File.real_path "/usr/local/bin/dppm"))))))
    elsif Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end
end
