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
          alias: 'i',
          info:  "Application's informations from its pkg.yml.
        Special path: `.` for all document, `version` to get the package's version",
          action:    "puts ::Package.info",
          arguments: %w(application path),
          variables: {
            prefix: {
              info:    "Path for dppm packages, sources and apps",
              default: "#{PREFIX}",
            },
          },
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
              action: "List.new().all",
            },
            applications: {
              alias:  "app",
              info:   "Installed applications",
              action: "List.new().app",
            },
            packages: {
              alias:  "pkg",
              info:   "Builded packages",
              action: "List.new().pkg",
            },
            source: {
              alias:  "src",
              info:   "Packages source",
              action: "List.new().src",
            },
            services: {
              info:   "Applications' services ",
              action: "List.new().services",
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
              arguments: %w(package variables...),
              action:    "::Package::CLI.new.add",
              options:   {
                contained: {
                  short: 'c',
                  info:  "with self-contained dependencies (no library symlinks)",
                },
              },
            },
            build: {
              alias:     'b',
              info:      "Build a package",
              arguments: %w(package variables...),
              action:    "::Package::CLI.new.build",
            },
            cache: {
              alias:  'c',
              info:   "Update the packages source cache",
              action: "::Package::Cache.cli",
            },
            delete: {
              alias:     'd',
              info:      "Delete an added package",
              arguments: %w(package variables...),
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
        service: {
          alias:    's',
          info:     "Manage applications' services",
          commands: {
            status: {
              info:      "Service status",
              arguments: %w(services...),
              action:    "::Service.cli_status",
            },
            boot: {
              info:      "Auto-start the service at boot",
              arguments: %w(service state),
              action:    "::Service.cli_boot",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "puts Localhost.service.system.new().start",
            },
            stop: {
              info:      "Stop the service",
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
    when "help" then puts ex; exit 0
    else             abort ex
    end
  end

  struct List
    @path : ::Package::Path

    def initialize(prefix)
      @path = ::Package::Path.new prefix
    end

    def all
      puts "applications:"
      app
      puts "\npackages:"
      pkg
      puts "\nsource:"
      src
      puts "\nservices run boot:"
      services
    end

    def app
      Dir.each_child(@path.app) { |app| puts app }
    end

    def pkg
      Dir.each_child(@path.pkg) { |pkg| puts pkg }
    end

    def src
      Dir.each_child(@path.src) { |src| puts src if src[0].ascii_lowercase? }
    end

    def services
      Dir.each_child(@path.app) do |app|
        service = Localhost.service.system.new app
        if service.exists?
          puts app + "\t#{(r = service.run?) ? r.colorize.green : r.colorize.red} #{(b = service.boot?) ? b.colorize.green : b.colorize.red}"
        end
      end
    end
  end
end
