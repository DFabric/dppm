require "clicr"
require "./manager"
require "./config"
require "./logs"
require "./service"

module CLI
  extend self
  include Clicr

  def run
    __debug = false
    create(
      name: "dppm",
      info: "The DPlatform Package Manager",
      variables: {
        prefix: {
          info:    "Base path for dppm packages, sources and apps",
          default: Manager::PREFIX,
        },
        config: {
          info:    "Configuration file path",
          default: "#{MainConfig.file}",
        },
        mirror: {
          info: "Mirror of precompiled applications (default in #{MainConfig.file})",
        },
        source: {
          info: "Source path/url of the packages and configurations (default in #{MainConfig.file})",
        },
      },
      options: {
        debug: {
          short: 'd',
          info:  "Debug print with error backtraces",
        },
        no_confirm: {
          short: 'y',
          info:  "No confirmations",
        },
      },
      commands: {
        app: {
          alias:    'a',
          info:     "Manage applications",
          commands: {
            add: {
              alias:     'a',
              info:      "Add a new application package (and build its missing dependencies)",
              arguments: %w(application custom_vars...),
              action:    "Manager::Application::CLI.add",
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
              variables: {
                database: {
                  info: "Database application to use",
                },
                web_server: {
                  info: "Web server serving the application as a public website",
                },
                url: {
                  info: "URL address (like https://myapp.example.net or http://[::1]/myapp), usually used with a web server",
                },
              },
            },
            config: {
              alias:   'c',
              info:    "Manage application's configuration",
              options: {
                nopkg: {
                  short: 'n',
                  info:  "Don't use pkg file, directly use the application's configuration file",
                },
              },
              commands: {
                get: {
                  info:      "Get a value. Single dot path `.` for all keys",
                  arguments: %w(application path),
                  action:    "puts Manager::Application::ConfigCLI.get",
                },
                set: {
                  info:      "Set a value",
                  arguments: %w(application path value),
                  action:    "Manager::Application::ConfigCLI.set() && puts %(done)",
                },
                del: {
                  info:      "Delete a path",
                  arguments: %w(application path),
                  action:    "Manager::Application::ConfigCLI.del() && puts %(done)",
                },
              },
            },
            delete: {
              alias:     'd',
              info:      "Delete an added application",
              arguments: %w(application custom_vars...),
              action:    "Manager::Application::CLI.delete",
              options:   {
                keep_user_group: {
                  short: 'k',
                  info:  "Don't delete the system user and groupof the application",
                },
                preserve_database: {
                  short: 'p',
                  info:  "Preserve the database used by the application from deletion",
                },
              },
            },
            exec: {
              alias:     'e',
              info:      "Execute an application in the foreground",
              arguments: %w(application),
              action:    "Manager::Application::CLI.exec",
            },
            list: {
              alias:  'l',
              info:   "List applications",
              action: "Manager::ListCLI.app",
            },
            query: {
              alias:     'q',
              info:      "Query informations from an application - `.` for the whole document",
              arguments: %w(application path),
              action:    "puts Manager::Application::CLI.query",
            },
            version: {
              alias:     'v',
              info:      "Returns application's version",
              arguments: %w(application),
              action:    "puts Manager::Application::CLI.version",
            },
          },
        },
        list: {
          alias:  'L',
          info:   "List all applications, packages and sources",
          action: "::Manager::ListCLI.all",
        },
        logs: {
          alias:     'l',
          info:      "Logs of the application's service",
          arguments: %w(application),
          action:    "Logs.get() { |log| print log }",
          options:   {
            error: {
              short: 'e',
              info:  "Print error logs instead of output logs",
            },
            follow: {
              short: 'f',
              info:  "Follow new lines, starting to the last 10 lines by default",
            },
          },
          variables: {
            lines: {
              info: "Number of last lines to print. All lines when no set",
            },
          },
        },
        package: {
          alias:     'p',
          info:      "Manage built packages",
          variables: {
            version: {
              info: "Package version",
            },
          },
          commands: {
            build: {
              alias:     'b',
              info:      "Build a package",
              arguments: %w(package custom_vars...),
              action:    "Manager::Package::CLI.build",
            },
            clean: {
              alias:  'c',
              info:   "Clean unused built packages by the applications",
              action: "clean_unused_packages",
            },
            delete: {
              alias:     'd',
              info:      "Delete a built package",
              arguments: %w(package custom_vars...),
              action:    "Manager::Package::CLI.delete",
            },
            list: {
              alias:  'l',
              info:   "List packages",
              action: "Manager::ListCLI.pkg",
            },
            query: {
              alias:     'q',
              info:      "Query informations from a package - `.` for the whole document.",
              arguments: %w(package path),
              action:    "puts Manager::Package::CLI.query",
            },
          },
        },
        service: {
          alias:    'S',
          info:     "Manage application services",
          commands: {
            boot: {
              info:      "Auto-start the service at boot",
              arguments: %w(service state),
              action:    "Manager::ServiceCLI.boot",
            },
            reload: {
              info:      "Reload the service",
              arguments: %w(service),
              action:    "service().reload || exit 1",
            },
            restart: {
              info:      "Restart the service",
              arguments: %w(service),
              action:    "service().restart || exit 1",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "service().start || exit 1",
            },
            status: {
              info:      "Status for specified services or all services if none set",
              arguments: %w(services...),
              action:    "Manager::ServiceCLI.status",
              options:   {
                all: {
                  short: 'a',
                  info:  "list all system services",
                },
                noboot: {
                  info: "don't include booting status",
                },
                norun: {
                  info: "don't include running status",
                },
              },
            },
            stop: {
              info:      "Stop the service",
              arguments: %w(service),
              action:    "service().stop || exit 1",
            },
          },
        },
        source: {
          alias:    's',
          info:     "Manage packages source mirrors",
          commands: {
            cache: {
              alias:  'c',
              info:   "Update the source cache. `-y` to force update",
              action: "update",
            },
            list: {
              alias:  'l',
              info:   "List source packages",
              action: "Manager::ListCLI.src",
            },
            query: {
              alias:     'q',
              info:      "Query informations from a source package - `.` for the whole document",
              arguments: %w(package path),
              action:    "puts query_src",
            },
          },
        },
        server: {
          info:   "Start the dppm API server",
          action: "puts server",
        },
        version: {
          alias:  'v',
          info:   "Version with general system information",
          action: "version",
        },
      }
    )
  rescue ex : Help
    Log.output.puts ex
  rescue ex : ArgumentRequired | UnknownCommand | UnknownOption | UnknownVariable
    abort ex
  rescue ex
    if __debug
      ex.inspect_with_backtrace Log.error
    else
      Log.error ex.to_s
    end
    exit 1
  end

  def version(**args)
    puts {{"DPPM build: " + `date "+%Y-%m-%d"`.stringify.chomp + " [" + `git describe --tags --long --always`.stringify.chomp + "]\n\n"}}
    Host.vars.each do |k, v|
      puts k + ": " + v
    end
  end

  def server(**args)
    "available soon!"
  end

  def service(service, **args)
    Service.init.new service
  end

  def update(config, source, prefix, no_confirm, **args)
    prefix = Prefix.new prefix, create: true
    if !source
      MainConfig.file = config
    end
    prefix.update source, no_confirm
  end

  def query_src(prefix, package, path, **args)
    pkg_file = Prefix.new(prefix).new_src(package).pkg_file
    Manager::Query.new(pkg_file.any).pkg(path).to_pretty_con
  end

  def clean_unused_packages(no_confirm, prefix, **args)
    Prefix.new(prefix).clean_unused_packages !no_confirm do
      Manager.cli_confirm
    end
  end
end

CLI.run
