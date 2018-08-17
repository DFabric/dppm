require "clicr"

CONFIG_FILE = "./config.ini"
PREFIX      = "/opt/dppm"

module CLI
  extend self
  # Global constant variables
  VERSION = "2018-alpha"

  def run
    Clicr.create(
      name: "dppm",
      info: "The DPlatform Package Manager",
      commands: {
        config: {
          alias:   'c',
          info:    "Manage application's configuration",
          options: {
            nopkg: {
              short: 'n',
              info:  "Don't use pkg.yml, directly use the application's configuration file",
            },
          },
          commands: {
            get: {
              info:      "Get a value. Single dot path `.` for all keys",
              arguments: %w(application path),
              action:    "puts ::ConfFile::CLI.get",
            },
            set: {
              info:      "Set a value",
              arguments: %w(application path value),
              action:    "puts ::ConfFile::CLI.set",
            },
            del: {
              info:      "Delete a path",
              arguments: %w(application path),
              action:    "puts ::ConfFile::CLI.del",
            },
          },
          variables: {
            prefix: {
              info:    "Path for dppm packages, sources and apps",
              default: "#{PREFIX}",
            },
          },
        },
        info: {
          alias:  'i',
          info:   "General system information",
          action: "info",
        },
        list: {
          alias:     'l',
          info:      "List applications, packages, sources or services",
          variables: {
            prefix: {
              info:    "Path for dppm packages, sources and apps",
              default: "#{PREFIX}",
            },
          },
          commands: {
            all: {
              alias:  'a',
              info:   "List everything",
              action: "::Package::List.new().all",
            },
            applications: {
              alias:  "app",
              info:   "Installed applications",
              action: "::Package::List.new().app { |app| puts app }",
            },
            packages: {
              alias:  "pkg",
              info:   "Builded packages",
              action: "::Package::List.new().pkg { |pkg| puts pkg }",
            },
            source: {
              alias:  "src",
              info:   "Packages source",
              action: "::Package::List.new().src { |src| puts src }",
            },
            services: {
              alias:  's',
              info:   "Applications' services ",
              action: "::Package::List.new().services_cli",
            },
          },
        },
        package: {
          options: {
            noconfirm: {
              short: 'y',
              info:  "No confirmations",
            },
          },
          alias:    'p',
          info:     "Operations relative to package management",
          commands: {
            add: {
              alias:     'a',
              info:      "Add a new package (and build its missing dependencies)",
              arguments: %w(package custom_vars...),
              action:    "::Package::CLI.new.add",
              options:   {
                contained: {
                  short: 'c',
                  info:  "No shared dependencies, copy instead of symlinks",
                },
                noservice: {
                  short: 'n',
                  info:  "Don't add a system service",
                },
                socket: {
                  short: 's',
                  info:  "Use of an UNIX socket instead of a port",
                },
              },
            },
            build: {
              alias:     'b',
              info:      "Build a package",
              arguments: %w(package custom_vars...),
              action:    "::Package::CLI.new.build",
            },
            cache: {
              alias:  'c',
              info:   "Update the packages source cache. `-y` to force",
              action: "::Package::Cache.cli",
            },
            delete: {
              alias:     'd',
              info:      "Delete an added package",
              arguments: %w(package custom_vars...),
              action:    "::Package::CLI.new.delete",
            },
          },
          variables: {
            config: {
              info:    "Configuration file path",
              default: "#{CONFIG_FILE}",
            },
            mirror: {
              info: "Mirror of precompiled applications (default in `config`)",
            },
            pkgsrc: {
              info: "Source of the packages' pkg.yml and configurations (default in `config`)",
            },
            prefix: {
              info:    "Path for dppm packages, sources and apps",
              default: "#{PREFIX}",
            },
          },
        },
        query: {
          alias:    'q',
          info:     "Query packages's informations from its pkg.yml. `.` for the whole document, `version` for the package's version",
          commands: {
            app: {
              info:      "Installed application",
              arguments: %w(package path),
              action:    "puts ::Package::Info.app_cli",
            },
            pkg: {
              info:      "Builded packages",
              arguments: %w(package path),
              action:    "puts ::Package::Info.pkg_cli",
            },
            src: {
              info:      "Source package",
              arguments: %w(package path),
              action:    "puts ::Package::Info.src_cli",
            },
          },
          variables: {
            prefix: {
              info:    "Path for dppm packages, sources and apps",
              default: "#{PREFIX}",
            },
          },
        },
        service: {
          alias:    's',
          info:     "Manage applications' services",
          commands: {
            status: {
              info:      "Service status",
              arguments: %w(services...),
              action:    "Localhost.service.cli_status",
            },
            boot: {
              info:      "\t Auto-start the service at boot",
              arguments: %w(service state),
              action:    "Localhost.service.cli_boot",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "puts Localhost.service.system.new().start",
            },
            stop: {
              info:      "\t Stop the service",
              arguments: %w(service),
              action:    "puts Localhost.service.system.new().stop",
            },
            restart: {
              info:      "Restart the service",
              arguments: %w(service),
              action:    "puts Localhost.service.system.new().restart",
            },
            reload: {
              info:      "Reload the service",
              arguments: %w(service),
              action:    "puts Localhost.service.system.new().reload",
            },
            logs: {
              info:      "\t Service's logs",
              arguments: %w(service),
              action:    "puts Localhost.service.logs_cli",
              options:   {
                error: {
                  short: 'e',
                  info:  "Print error logs instead of output logs",
                },
              },
            },
          },
        },
        server: {
          info:   "Start the dppm API server",
          action: "puts \"available soon!\".to_s",
        },
      }
    )
  rescue ex
    case ex.cause.to_s
    when "help"                                                            then puts ex; exit 0
    when "argument_required", "unknown_option", "unknown_command_variable" then abort ex
    else                                                                        Log.error ex.to_s
    end
  end

  def info
    puts {{"DPPM build: " + `date "+%Y-%m-%d"`.stringify + '\n'}}
    Localhost.vars.each do |k, v|
      puts k + ": " + v
    end
  end
end
