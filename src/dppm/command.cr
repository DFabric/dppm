struct Command
  # Global constant variables
  VERSION = "2018-alpha"

  USAGE = <<-USAGE
  dppm - The DPlatform Package Manager
  Usage: dppm [command] [package] [variables] [--] [options]

  Command:
      a, add                   add a new package (and build its missing dependencies)
      b, build                 build a package
      d, delete                delete an added package
      m, migrate               migrate to an other app version (default: latest)
      s, service               service operations
      c, clone                 clone an existing application
      l, list [app|pkg|src]    list applications, packages and sources
      v, version               show the version
      h, help                  show this help
      cache                    update the cache from `pkgsrc` (from file or variable)
      check                    various checks like updates, installation
      server                   run the API server
      config                   get/set/del configuration variables
      pkg                      query informations on the package
      vars                     show the help for variables

  Options:
      --config=[path]           specify a configuration file
      -v, --version             show the version
      -h, --help                show this help
      -y, --yes                 no confirmations
      --contained               with self-contained dependencies (no library symlinks)

  USAGE

  SERVICE = <<-SERVICE
  Usage: dppm service [application] [command]

  Service commands:
      run [true|false]         run the service
      boot [true|false]        auto-start the service at boot
      restart                  restart the service
      reload                   reload the service if available

  No arguments after the `run` and `boot` command will return their current status

  SERVICE

  VARS = <<-VARS
  Usage: dppm [...] [variable]=[value] [variable1]=[value1] ...

  Variables:
      prefix                    where is the package (default: /opt/dppm)
      pkgsrc                    source of the packages
      mirror                    mirror of precompiled applications
      name                      name of the package (default: uuid)
      tag                       a tag describing a version, like 'latest'
      user                      uid or user to be used
      group                     gid or group to be used
      owner                     regroup the user and group using a same id/name
      port                      use the specified port
      webserver (default: none) use the specified webserver
      domains

  System variables (will be overridden if set):
      package                  name of the package
      pkgdir                   destination directory, prefix + pkgname
      arch                     architecture of the CPU
      arch_alias               if the architecture is called differently
      kernel                   name of the currently used kernel
      kernel_version           version of the currently used kernel
      sysinit                  the operating system's init system

  Other variables:
      variable=value           only a-z, 0-9 and _ are allowed
  VARS

  PKG = <<-PKG
  Usage: dppm pkg [package] [key]

  Key:
      version
      versions
      deps
      package
      name
      url
      type
      category
      license
      docs
      description
      info
      tags (tag name)

  PKG

  CONFIG = <<-CONFIG
  Usage: dppm config [operation] [package]

  Operation:
      list                          list available variables
      file                          output the configuration file
      config get [keys]             get the value of a key
      config set [keys] [value]     set or change a new value for a key
      config del [keys]             delete a key entry (not recommended)

  keys represented as an array like `[key0, kye1, key2]` will directly query into
  the configuration file.
  a key as a string like `key` will query the variables defined in the pkg.yml,
  that will point to the configuration file.

  CONFIG

  CHECK = <<-CHECK
  Usage: dppm check [type]

  Type:
     list                          list available variables
     file                          output the configuration file
     config get [keys]             get the value of a key
     config set [keys] [value]     set or change a new value for a key
     config del [keys]             delete a key entry (not recommended)

  keys represented as an array like `[key0, kye1, key2]` will directly query into
  the configuration file.
  a key as a string like `key` will query the variables defined in the pkg.yml,
  that will point to the configuration file.

  CHECK

  @noconfirm = false

  def run
    case ARGV[0]?
    when "a", "add", "b", "build", "d", "delete"
      Log.error "package name: none provided" if !ARGV[1]?
      task = Tasks.init ARGV[0], ARGV[1], arg_parser(ARGV[2..-1])
      Log.info ARGV[0], task.simulate
      task.run if @noconfirm || Tasks.confirm ARGV[0]
    when "m", "migrate"
      puts "implemented soon!"
    when "service"
      service = Localhost.service.system.new ARGV[1]
      puts case ARGV[2]?
      when "run"    then ARGV[3]? ? service.run Utils.to_b(ARGV[3]) : service.run?
      when "boot"   then ARGV[3]? ? service.boot Utils.to_b(ARGV[3]) : service.boot?
      when "reload" then service.reload
      when nil      then puts SERVICE
      else
        raise "unknwon argument: " + ARGV[2]
      end
      exit
    when "l", "list"
      case ARGV[1]?
      when "app", "pkg", "src" then list ARGV[1]
      when nil
        puts "app:"
        list "app"
        puts "\npkg:"
        list "pkg"
        puts "\nsrc:"
        list "src"
      else
        raise "unknwon argument: " + ARGV[1]
      end
    when "cache"
      case ARGV[1]?
      when nil
        Command.cache(YAML.parse(File.read "./config.yml")["pkgsrc"].as_s)
      when .starts_with? "pkgsrc="
        Command.cache ARGV[1][7..-1]
      when .starts_with? "--config="
        Command.cache(YAML.parse(File.read ARGV[1][9..-1])["pkgsrc"].as_s)
      else
        Command.cache(YAML.parse(File.read "./config.yml")["pkgsrc"].as_s)
      end
    when "pkg"
      puts "no implemented yet"
      puts Pkg.new(ARGV[1]).version
    when "config" then config
    when "server" then server
    when "check"
      puts "no implemented yet"
    when "vars"
      puts VARS
    when "h", "help", "-h", "--help"
      puts USAGE
    when nil
      puts USAGE
      exit 1
    else
      puts USAGE
      Log.error "unknown command: #{ARGV.first?}"
    end
  rescue ex
    Log.error ex.to_s
  end

  def arg_parser(vars : Array(String))
    h = Hash(String, String).new
    conf_file = YAML::Any.new("")
    vars.each do |arg|
      case arg
      when .starts_with? "--config=" then conf_file = YAML.parse(File.read arg[9..-1])
      when "-y", "--yes"             then @noconfirm = true
      when "--contained"             then h["--contained"] = "true"
      when .includes? '='
        var = arg.split '='
        raise "only `a-z`, `A-Z`, `0-9` and `_` are allowed as variable name: " + arg if !var[0].ascii_alphanumeric_underscore?
        h[var[0]] = var[1]
      else
        raise "invalid argument: #{arg}"
      end
    end
    begin
      conf_file = YAML.parse(File.read "./config.yml") if conf_file.as_s?
      h["pkgsrc"] ||= conf_file["pkgsrc"].as_s
      h["mirror"] ||= conf_file["mirror"].as_s
    rescue ex
      raise "failed to get a configuraration file: #{ex}"
    end
    h
  end

  # Download a cache of package sources
  def self.cache(pkgsrc, src = Tasks::Path.new.src, check = false)
    # Update cache if older than 2 days
    if !(File.exists?(src) || File.symlink?(src)) ||
       Time.utc_now.to_s("%Y%m%d").to_i - File.lstat(src).ctime.to_s("%Y%m%d").to_i > 2
      FileUtils.rm_r src if File.exists? src
      if Utils.is_http? pkgsrc
        HTTPget.file pkgsrc, src + ".tar.gz"
        tmp = File.dirname(src)
        Exec.new("/bin/tar", ["zxf", src + ".tar.gz", "-C", tmp]).out
        File.delete src + ".tar.gz"
        File.rename Dir[tmp + "/*packages-source*"][0], src
        Log.info "cache updated", src
      else
        File.symlink File.real_path(pkgsrc), src
        Log.info "symlink added from `#{File.real_path(pkgsrc)}`", src
      end
    end
  end
  
  def list(dir)
    case dir
    when "app"
      Dir.each_child(Tasks::Path.new.app) { |c| puts c }
    when "pkg"    
      Dir.each_child(Tasks::Path.new.pkg) { |c| puts c }
    when "src"
      Dir.each_child(Tasks::Path.new.src) { |c| puts c if c[0].ascii_lowercase? }
    end
  end

  private def config
    case ARGV[1]
    when "get" then return puts ConfFile::Config.new(Dir.current + '/' + ARGV[2]).get ARGV[3]
    when "set" then ConfFile::Config.new(Dir.current + '/' + ARGV[2]).set ARGV[3], ARGV[4]
    when "del" then ConfFile::Config.new(Dir.current + '/' + ARGV[2]).get ARGV[3]
    else
      raise "config - unknwon argument: " + ARGV[1]
    end
    puts "done"
  end

  private def server
    # Server.new.run
    puts "api server not implemented yet"
  end
end
