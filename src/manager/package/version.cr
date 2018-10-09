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

    if src
      if (src_array = src.as_a?)
        src_array.map &.as_s
      else
        versions = Array(String).new
        HTTPget.string(src.to_s).each_line do |line|
          versions << $0 if line =~ /#{regex}/
        end
        versions
      end
    else
      raise "no source url"
    end
  end
end
