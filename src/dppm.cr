module DPPM
  class Error < Exception
  end

  extend self

  def build_date : String
    {{ `date --utc -Iminutes`.stringify.chomp }}
  end

  def build_commit : String
    {{ `git rev-parse --short HEAD`.stringify.chomp }}
  end

  def version : String
    {{ `git show -s --format=%ci`.split(' ')[0].gsub(/-/, ".") }}
  end
end
