require "socket"
require "exec"

struct Localhost
  getter proc_ver : Array(String) = File.read("/proc/version").split(' ')
  getter kernel : String = proc_ver[0].downcase
  getter kernel_ver : String = proc_ver[2].split('-')[0]
  getter sysinit : String = getsysinit
  getter arch : String = getarch
  getter vars : Hash(String, String) = getvars
  getter service = Service.init sysinit

  # All system environment variables
  private def getvars
    h = Hash(String, String).new
    {% for var in ["arch", "kernel", "kernel_ver", "sysinit"] %}
    {
      h[{{var}}] = {{var.id}}
    }
    {% end %}
    h
  end

  private def getarch
    case File.read "/proc/kallsyms"
    when .includes? " x86_64_"  then "x86-64"
    when .includes? " x86_"     then "x86"
    when .includes? " aarch64_" then "aarch64"
    when .includes? " armv7_"   then "armhf"
    else
      raise "unsupported architecure: " + arch
    end
  end

  private def getsysinit
    init = File.basename File.real_path "/sbin/init"
    case init
    when "systemd", "init" then init
    else
      raise "unsupported init system, consider to migrate to OpenRC if you are still in init.d: " + init
    end
  end

  def port(port_num : Int32, port_used = Array(Int32).new, &log : String, String, String -> Nil)
    h = Hash(Int32, Array(Int32)).new
    raise "the limit of 65535 for port numbers is reached" if port_num > 65535
    begin
      # tcp port available?
      TCPServer.new(port_num).close
      # ipv4 udp port available?
      ip4 = UDPSocket.new Socket::Family::INET
      ip4.bind "127.0.0.1", port_num
      ip4.close
      # ipv6 udp port available?
      ip6 = UDPSocket.new Socket::Family::INET6
      ip6.bind "::1", port_num
      ip6.close
      yield "WARN", "ports unavailable or used", port_used.join ", " if !port_used.empty?
      port_num
    rescue
      port port_num + 1, port_used << port_num, &log
    end
  end

  def run(task, vars, &log : String, String, String -> Nil)
    Cmd::Run.new task, vars, &log
  end
end

#
#
# System.vars.each do |var|
#  puts "#{var}=\"#{System.vars[var]}\""
# end
