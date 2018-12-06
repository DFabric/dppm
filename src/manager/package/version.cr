module Manager::Package::Version
  extend self

  def all(kernel : String, arch : String, pkg) : Array(String)
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

  def from_tag(tag : String, pkg_file) : String
    src = pkg_file.tags[tag]["src"].as_s
    # Test if the src is an URL or a version number
    if Utils.is_http? src
      regex = if regex_tag = pkg_file.tags[tag]["regex"]?
                regex_tag
              else
                pkg_file.tags["self"]["regex"]
              end.as_s
      /(#{regex})/ =~ HTTPget.string(src)
      $1
    else
      src
    end
  end
end
