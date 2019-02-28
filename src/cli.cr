require "clicr"
require "./prefix"
require "./cli/*"

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
          default: Prefix::DEFAULT_PATH,
        },
        config: {
          info:    "Configuration file path",
          default: "#{Prefix::Config.file}",
        },
        mirror: {
          info: "Mirror of precompiled applications (default in #{Prefix::Config.file})",
        },
        source: {
          info: "Source path/url of the packages and configurations (default in #{Prefix::Config.file})",
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
              action:    "App.add",
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
                  action:    "App.config_get",
                },
                set: {
                  info:      "Set a value",
                  arguments: %w(application path value),
                  action:    "App.config_set() && Log.output.puts %(done)",
                },
                del: {
                  info:      "Delete a path",
                  arguments: %w(application path),
                  action:    "App.config_del() && Log.output.puts %(done)",
                },
              },
            },
            delete: {
              alias:     'd',
              info:      "Delete an added application",
              arguments: %w(application custom_vars...),
              action:    "App.delete",
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
              action:    "App.exec",
            },
            list: {
              alias:  'l',
              info:   "List applications",
              action: "List.app",
            },
            query: {
              alias:     'q',
              info:      "Query informations from an application - `.` for the whole document",
              arguments: %w(application path),
              action:    "Log.output.puts App.query",
            },
            version: {
              alias:     'v',
              info:      "Returns application's version",
              arguments: %w(application),
              action:    "Log.output.puts App.version",
            },
          },
        },
        list: {
          alias:  'l',
          info:   "List all applications, packages and sources",
          action: "List.all",
        },
        logs: {
          alias:     'L',
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
              action:    "Pkg.build",
            },
            clean: {
              alias:  'c',
              info:   "Clean unused built packages by the applications",
              action: "Pkg.clean_unused_packages",
            },
            delete: {
              alias:     'd',
              info:      "Delete a built package",
              arguments: %w(package custom_vars...),
              action:    "Pkg.delete",
            },
            list: {
              alias:  'l',
              info:   "List packages",
              action: "List.pkg",
            },
            query: {
              alias:     'q',
              info:      "Query informations from a package - `.` for the whole document.",
              arguments: %w(package path),
              action:    "Log.output.puts Pkg.query",
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
              action:    "Service.boot",
            },
            reload: {
              info:      "Reload the service",
              arguments: %w(service),
              action:    "Service.new().reload || exit 1",
            },
            restart: {
              info:      "Restart the service",
              arguments: %w(service),
              action:    "Service.new().restart || exit 1",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "Service.new().start || exit 1",
            },
            status: {
              info:      "Status for specified services or all services if none set",
              arguments: %w(services...),
              action:    "Service.status",
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
              action:    "Service.new().stop || exit 1",
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
              action: "Src.update",
            },
            list: {
              alias:  'l',
              info:   "List source packages",
              action: "List.src",
            },
            query: {
              alias:     'q',
              info:      "Query informations from a source package - `.` for the whole document",
              arguments: %w(package path),
              action:    "Log.output.puts Src.query",
            },
          },
        },
        server: {
          info:   "Start the dppm API server",
          action: "Log.output.puts server",
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
    Log.output.puts {{"DPPM build: " + `date "+%Y-%m-%d"`.stringify.chomp + " [" + `git describe --tags --long --always`.stringify.chomp + "]\n\n"}}
    Host.vars.each do |k, v|
      Log.output.puts k + ": " + v
    end
  end

  def server(**args)
    "available soon!"
  end

  def query(any : CON::Any, path : String) : CON::Any
    case path
    when "." then any
    else          any[Utils.to_array path]
    end
  end

  def confirm_prompt
    Log.output.puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               abort "cancelled."
    end
  end
end
