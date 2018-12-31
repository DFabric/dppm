require "clicr"
require "./manager"
require "./config"
require "./logs"
require "./logger"
require "./service"

module CLI
  extend self
  include Clicr

  def run
    create(
      name: "dppm",
      info: "The DPlatform Package Manager",
      variables: {
        prefix: {
          info:    "Base path for dppm packages, sources and apps",
          default: Manager::PREFIX,
        },
      },
      commands: {
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
        manager: {
          alias:   'm',
          info:    "Operations relative to package management",
          options: {
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
                },
                delete: {
                  alias:     'd',
                  info:      "Delete an added application",
                  arguments: %w(application custom_vars...),
                  action:    "Manager::Application::CLI.delete",
                  options:   {
                    keep_user_group: {
                      short: 'k',
                      info:  "Don't delete the user and group (for application)",
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
            package: {
              alias:    'p',
              info:     "Manage built packages",
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
                  action: "::Manager::Package::CLI.clean",
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
            source: {
              alias:    's',
              info:     "Manage packages source mirrors",
              commands: {
                cache: {
                  alias:  'c',
                  info:   "Update the source cache. `-y` to force update",
                  action: "Manager::Source::Cache.cli",
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
                  action:    "puts Manager::Source::CLI.query",
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
                  action:    "puts Manager::ConfigCLI.get",
                },
                set: {
                  info:      "Set a value",
                  arguments: %w(application path value),
                  action:    "Manager::ConfigCLI.set() && puts %(done)",
                },
                del: {
                  info:      "Delete a path",
                  arguments: %w(application path),
                  action:    "Manager::ConfigCLI.del() && puts %(done)",
                },
              },
            },
            list: {
              alias:  'l',
              info:   "List all applications, packages and sources",
              action: "::Manager::ListCLI.all",
            },
          },
          variables: {
            config: {
              info:    "Configuration file path",
              default: "#{Manager::MainConfig::FILE}",
            },
            mirror: {
              info: "Mirror of precompiled applications (default in #{Manager::MainConfig::FILE})",
            },
            source: {
              info: "Source path/url of the packages and configurations (default in #{Manager::MainConfig::FILE})",
            },
          },
        },
        service: {
          alias:    's',
          info:     "Manage applications' services",
          commands: {
            boot: {
              info:      "Auto-start the service at boot",
              arguments: %w(service state),
              action:    "Service::CLI.boot",
            },
            reload: {
              info:      "Reload the service",
              arguments: %w(service),
              action:    "puts service().reload",
            },
            restart: {
              info:      "Restart the service",
              arguments: %w(service),
              action:    "puts service().restart",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "puts service().start",
            },
            status: {
              info:      "Status for specified services or all services if none set",
              arguments: %w(services...),
              action:    "Service::CLI.status",
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
              action:    "puts service().stop",
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
    puts ex; exit 0
  rescue ex : ArgumentRequired | UnknownCommand | UnknownOption | UnknownVariable
    abort ex
  rescue ex
    Log.error ex.to_s
  end

  def version(prefix)
    puts {{"DPPM build: " + `date "+%Y-%m-%d"`.stringify.chomp + " [" + `git describe --tags --long --always`.stringify.chomp + "]\n\n"}}
    Host.vars.each do |k, v|
      puts k + ": " + v
    end
  end

  def server(prefix)
    "available soon!"
  end

  def service(prefix, service)
    Host.service.new service
  end
end
