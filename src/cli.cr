require "clicr"
require "exec"
require "./manager"
require "./config"
require "./logger"
require "./service"
require "./system"

# Global constant variables
CONFIG_FILE = "./config.ini"
PREFIX      = (::System::Owner.root? ? "/opt" : ENV["HOME"]) + "/dppm"

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
          default: PREFIX,
        },
      },
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
              action:    "puts ::Config::CLI.get",
            },
            set: {
              info:      "Set a value",
              arguments: %w(application path value),
              action:    "Config::CLI.set() && puts %(done)",
            },
            del: {
              info:      "Delete a path",
              arguments: %w(application path),
              action:    "Config::CLI.del() && puts %(done)",
            },
          },
        },
        exec: {
          alias:     'e',
          info:      "Execute an application in the foreground",
          arguments: %w(application),
          action:    "exec",
        },
        list: {
          alias:    'l',
          info:     "List applications, packages, sources or services",
          commands: {
            all: {
              alias:  'a',
              info:   "\t List everything",
              action: "::Manager::List.new().all",
            },
            applications: {
              alias:  "app",
              info:   "Installed applications",
              action: "Manager::List.new().app { |app| puts app }",
            },
            packages: {
              alias:  "pkg",
              info:   "Builded packages",
              action: "Manager::List.new().pkg { |pkg| puts pkg }",
            },
            source: {
              alias:  "src",
              info:   "\t Managers source",
              action: "Manager::List.new().src { |src| puts src }",
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
                  action:    "Manager::Application::CLI.new.add",
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
                      info:  "\t Use of an UNIX socket instead of a port",
                    },
                  },
                },
                delete: {
                  alias:     'd',
                  info:      "Delete an added application",
                  arguments: %w(application custom_vars...),
                  action:    "::Manager::Application::CLI.new.delete",
                  options:   {
                    keep_user_group: {
                      short: 'k',
                      info:  "Don't delete the user and group (for application)",
                    },
                  },
                },
              },
            },
            cache: {
              alias:  'c',
              info:   "Update the packages source cache. `-y` to force update",
              action: "Manager::Cache.cli",
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
                # clean: {
                # info:   "Clean built packages not used by any applications",
                # action: "::Manager::Cli.clean",
                # },
                delete: {
                  alias:     'd',
                  info:      "Delete a built package",
                  arguments: %w(package custom_vars...),
                  action:    "Manager::Package::CLI.delete",
                },
              },
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
          },
        },
        query: {
          alias:    'q',
          info:     "Query packages's informations from its pkg.yml. `.` for the whole document, `version` for the package's version",
          commands: {
            app: {
              info:      "Installed application",
              arguments: %w(package path),
              action:    "puts Manager::Info.app_cli",
            },
            pkg: {
              info:      "Builded packages",
              arguments: %w(package path),
              action:    "puts Manager::Info.pkg_cli",
            },
            src: {
              info:      "Source package",
              arguments: %w(package path),
              action:    "puts Manager::Info.src_cli",
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
              action:    "System::Host.service.cli_status",
              options:   {
                system: {
                  short: 's',
                  info:  "include system services",
                },
                noboot: {
                  info: "don't include booting status",
                },
                norun: {
                  info: "don't include running status",
                },
              },
            },
            boot: {
              info:      "\t Auto-start the service at boot",
              arguments: %w(service state),
              action:    "System::Host.service.cli_boot",
            },
            start: {
              info:      "Start the service",
              arguments: %w(service),
              action:    "puts service().start",
            },
            stop: {
              info:      "\t Stop the service",
              arguments: %w(service),
              action:    "puts service().stop",
            },
            restart: {
              info:      "Restart the service",
              arguments: %w(service),
              action:    "puts service().restart",
            },
            reload: {
              info:      "Reload the service",
              arguments: %w(service),
              action:    "puts service().reload",
            },
            logs: {
              info:      "\t Service's logs",
              arguments: %w(service),
              action:    "puts System::Host.service.cli_logs",
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

  def confirm
    puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               puts "cancelled."
    end
  end

  def version(prefix)
    puts {{"DPPM build: " + `date "+%Y-%m-%d"`.stringify + '\n'}}
    ::System::Host.vars.each do |k, v|
      puts k + ": " + v
    end
  end

  def exec(prefix, application)
    app_path = Path.new(prefix).app + '/' + application
    pkg = YAML.parse File.read app_path + "/pkg.yml"

    exec_start = pkg["exec"]["start"].as_s.split(' ')
    if env = pkg["env"]?
      env_vars = env.as_h.each_with_object({} of String => String) do |(key, value), memo|
        memo[key.as_s] = value.as_s
      end
    end

    Process.run command: exec_start[0],
      args: (exec_start[1..-1] if exec_start[1]?),
      env: env_vars,
      clear_env: true,
      shell: false,
      output: STDOUT,
      error: STDERR,
      chdir: app_path
  end

  def server(prefix)
    "available soon!"
  end

  def service(prefix, service)
    ::System::Host.service.system.new service
  end
end
