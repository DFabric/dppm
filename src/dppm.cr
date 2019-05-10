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
      Path[current_dir].parent.parent.parent.parent.parent.parent.to_s
    elsif File.exists? "/usr/local/bin/dppm"
      Path[File.real_path "/usr/local/bin/dppm"].parent.parent.parent.parent.parent.parent.to_s
    elsif Process.root? && Dir.exists? "/srv"
      "/srv/dppm"
    elsif xdg_data_home = ENV["XDG_DATA_HOME"]?
      xdg_data_home + "/dppm"
    else
      ENV["HOME"] + "/.dppm"
    end
  end
end
