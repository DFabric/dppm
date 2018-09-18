module Manager::Package::Version
  extend self

  def get(kernel, arch, pkg)
    # Set src and regex
    if hash = pkg["self"]?
      src = hash["src"]?
      regex = hash["regex"]?
    end

    if pkg_kernel = pkg[kernel]?
      if !regex
        raise "unsupported architecure: " + arch if !src
        regex = pkg_kernel[arch]
      end
    elsif !src && !regex
      raise "unsupported kernel: " + kernel
    end

    if src && (src_array = src.as_a?)
      src_array.map &.to_s
    else
      HTTPget.string(src.to_s).split('\n').map do |line|
        $0 if line =~ /#{regex}/
      end.compact!
    end
  end
end
