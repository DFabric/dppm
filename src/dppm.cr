require "colorize"
require "file_utils"
require "http/client"
require "option_parser"
require "openssl"
require "semantic_version"
require "yaml"

# Third party libraries
require "crest"
require "exec"
require "semantic_compare"

# Files
require "./dppm/**"
HOST  = Localhost.new
CACHE = "/tmp/dppm-package-sources/"

struct Command
  # Global constant variables
  VERSION = "2018-alpha"

  USAGE = <<-USAGE
  dppm - The DPlatform Package Manager
  Usage: dppm [command] [package] [variables] [--] [options]

  Command:
      a, add                   add a new pre-built package
      b, build                 build a package
      i, install               build then add a package
      d, delete                delete an installed package
      m, migrate               migrate to an other app version (default: latest)
      s, service               service operations
      c, clone                 clone an existing application
      l, list                  list available packages
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

  Variable:
      prefix                   where is the package (default: /opt)
      pkgsrc                   source of the packages
      mirror                   mirror of precompiled applications
      name                     name of the packqge (default: package name)
      tag                      a tag describing a version, like 'latest'
      user  (`add` task)       uid or user to be used for the program
      group (`add` task)       gid or group to be used for the program
      owner                    regroup the user and group using a same id/name

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
      infos
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
    begin
      case ARGV[0]?
      when "a", "add", "b", "build", "i", "install", "d", "delete", "m", "migrate"
        error "package name: none provided" if !ARGV[1]?
        task = Tasks.init(ARGV[0], ARGV[1], arg_parser(ARGV[2..-1])) { |log_type, title, msg| log log_type, title, msg }
        log "INFO", ARGV[0], task.simulate
        task.run if @noconfirm || Tasks.confirm ARGV[0]
      when "service"
        service = Localhost.new.service
        puts case ARGV[2]?
        when "run"    then ARGV[3]? ? service.run ARGV[1], Utils.to_b(ARGV[3]) : service.run ARGV[1]
        when "boot"   then ARGV[3]? ? service.boot ARGV[1], Utils.to_b(ARGV[3]) : service.boot ARGV[1]
        when "reload" then service.reload ARGV[1]
        when nil      then puts SERVICE
        else
          raise "unknwon argument: " + ARGV[2]
        end
        exit
      when "l", "list"
        Dir.each_child ARGV[1]? ? ARGV[1] : CACHE do |package|
          puts package if package =~ /^[a-z]+$/
        end
      when "cache"
        if ARGV[1]? =~ /^pkgsrc=(.*)/
          Command.cache $1 { |log_type, title, msg| log log_type, title, msg }
        elsif ARGV[1]? =~ /^--config=(.*)/
          Command.cache(YAML.parse(File.read $1)["pkgsrc"].as_s) { |log_type, title, msg| log log_type, title, msg }
        else
          Command.cache(YAML.parse(File.read "./config.yml")["pkgsrc"].as_s) { |log_type, title, msg| log log_type, title, msg }
        end
      when "pkg"
        puts "no implemented yet"
        puts Pkg.new(ARGV[1]).version
      when "config" then config
      when "check"
        puts "no implemented yet"
      when "server"
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
        error "unknown command: " + ARGV.first?.to_s
      end
    rescue ex
      error ex.to_s
    end
  end

  def arg_parser(vars : Array(String))
    h = Hash(String, String).new
    conf_file = YAML::Any.new("")
    vars.each do |arg|
      case arg
      when /^([a-z0-9_]+)=(.*)/ then h[$1] = $2
      when /^--config=(.*)/     then conf_file = YAML.parse(File.read $1)
      when /(.*)=(.*)/          then raise "only, `a-z`, `0-9` and `_` are allowed on passed variables: " + $1
      when "-y", "--yes"        then @noconfirm = true
      when "--contained"        then h["--contained"] = "true"
      else
        raise "invalid argument: #{arg}"
      end
    end
    begin
      conf_file = YAML.parse(File.read "./config.yml") if conf_file == ""
      h["pkgsrc"] ||= conf_file["pkgsrc"].as_s
      h["mirror"] ||= conf_file["mirror"].as_s
    rescue ex
      raise "failed to get a configuraration file: #{ex}"
    end
    h
  end

  # Download a cache of package sources
  def self.cache(pkgsrc, check = false, &log : String, String, String -> Nil)
    FileUtils.rm_r CACHE[0..-2] if File.exists? CACHE[0..-2]
    if pkgsrc =~ /^https?:\/\/.*/
      HTTPget.file pkgsrc, CACHE[0..-2] + ".tar.gz"
      Exec.new("/bin/tar", ["zxf", CACHE[0..-2] + ".tar.gz", "-C", "/tmp/"]).out
      File.delete CACHE[0..-2] + ".tar.gz"
      File.rename Dir["/tmp/*package-sources*"][0], CACHE
      yield "INFO", "cache updated", CACHE
    else
      File.symlink File.real_path(pkgsrc), CACHE[0..-2]
      yield "INFO", "symlink added from `#{File.real_path(pkgsrc)}`", CACHE
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
    service = Service.new
    Server.new
    Kemal.config.env = "production"
    Kemal.run
  end

  def log(log_type, title, msg) : Nil
    # This is for the case where the main  is wrong
    puts case log_type
    when "INFO" then "INFO".colorize.blue.mode(:bold).to_s + ' ' + title.colorize.white.to_s
    when "WARN" then "WARN".colorize.yellow.mode(:bold).to_s + ' ' + title.colorize.white.mode(:bold).to_s
    else
      raise "unknown log type: " + log_type
    end + ": " + msg
  end

  def error(msg, exit_code = 1)
    # This is for the case where the main  is wrong
    STDERR.puts "ERR!".colorize.red.mode(:bold).to_s + ' ' + msg.colorize.light_magenta.to_s
    exit exit_code
  end
end

Command.new.run
