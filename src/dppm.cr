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
end
