module Version
  extend self

  def get(kernel, arch, pkg)
    # Set src and regex
    src = pkg["self"]["src"] if pkg["self"]? && pkg["self"]["src"]?
    regex = pkg["self"]["regex"] if pkg["self"]? && pkg["self"]["regex"]?

    if pkg[kernel]?
      regex = pkg[kernel][arch] if !regex
      raise "arch unsupported: " + arch if !src && !regex
    elsif !src && !regex
      raise "unsupported kernel: " + kernel
    end
    if src && src.as_a?
      src.as_a.map { |s| s.to_s }
    else
      HTTPGet.string(src.to_s).split('\n').map do |line|
        /#{regex}/.match(line).not_nil![0] if line =~ /#{regex}/
      end.compact!
    end
  end
end
