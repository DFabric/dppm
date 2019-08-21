require "clicr"
require "./prefix"
require "./cli/*"

module DPPM::CLI
  extend self
  include Clicr

  macro run(**additional_commands)
  def DPPM::CLI.internal_run(**additional_commands)
    Clicr.create(
      name: "dppm",
      info: "The DPlatform Package Manager",
      variables: {
        prefix: {
          info:    "Base path for dppm packages, sources and apps",
          default: Prefix.default,
        },
        config: {
          info: "Configuration file path",
        },
        source_name: {
          info:    "Name of the source to get packages and configuration",
          default: Prefix.default_source_name,
        },
        source_path: {
          info: "Source path/url of the packages and configurations (default in the config file)",
        },
      },
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
          inherit:   \%w(config no_confirm prefix source_name source_path),
          variables: {
            group: {
              info:    "Group namespace where installing applications",
              default: Prefix.default_group,
            },
          },
          commands: {
            add: {
              alias:     'a',
              info:      "Add a new application (builds its missing dependencies)",
              action:    "App.add",
              arguments: \%w(application custom_vars...),
              inherit:   \%w(config group no_confirm prefix source_name source_path),
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
                  info: "Application name of the database to use",
                },
                name: {
                  info: "Name of the application to install",
                },
                tag: {
                  info: "Package version's tag (e.g: latest)",
                },
                url: {
                  info: "URL address (like https://myapp.example.net or http://[::1]/myapp), usually used with a web server",
                },
                version: {
                  info: "Package version",
                },
                web_server: {
                  info: "Application name of the web server serving this application as a public website",
                },
              },
            },
            config: {
              alias:   'c',
              info:    "Manage application's configuration",
              inherit: \%w(group nopkg prefix),
              options: {
                nopkg: {
                  short: 'n',
                  info:  "Don't use pkg file, directly use the application's configuration file",
                },
              },
              commands: {
                get: {
                  info:      "Get a value. Single dot path `.` for all keys",
                  action:    "App.config_get",
                  arguments: \%w(application path),
                  inherit:   \%w(group nopkg prefix),
                },
                set: {
                  info:      "Set a value",
                  action:    \%(App.config_set() && Log.output.puts "done"),
                  arguments: \%w(application path value),
                  inherit:   \%w(group nopkg prefix),
                },
                del: {
                  info:      "Delete a path",
                  action:    \%(App.config_del() && Log.output.puts "done"),
                  arguments: \%w(application path),
                  inherit:   \%w(group nopkg prefix),
                },
              },
            },
            delete: {
              alias:     'd',
              info:      "Delete an added application",
              action:    "App.delete",
              arguments: \%w(application),
              inherit:   \%w(group no_confirm prefix),
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
              action:    "App.exec",
              arguments: \%w(application),
              inherit:   \%w(prefix group),
            },
            query: {
              info:      "Get information of an application - `.` for the whole document",
              action:    "Log.output.puts App.info",
              arguments: \%w(application path),
              inherit:   \%w(prefix group),
            },
            install: {
              alias:   'i',
              info:    "Install DPPM to a new defined prefix",
              action:  "install_dppm",
              inherit: \%w(no_confirm config prefix group source_name source_path),
            },
            list: {
              alias:   'l',
              info:    "List applications",
              action:  "List.app",
              inherit: \%w(prefix),
            },
            logs: {
              alias:     'L',
              info:      "Read logs of the application's service - list log names if empty",
              action:    "App.logs() { |log| Log.output << log }",
              arguments: \%w(application log_names...),
              inherit:   \%w(prefix group),
              options:   {
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
            uninstall: {
              alias:  'U',
              info:   "Uninstall DPPM with all its applications",
              action: "uninstall_dppm",
              inherit:   \%w(config group no_confirm prefix source_name source_path),
            },
            upgrade: {
              alias:     'u',
              info:      "Upgrade the application to a version",
              action:    "App.upgrade",
              arguments: \%w(application custom_vars...),
              inherit:   \%w(config group no_confirm prefix source_name source_path),
              options: {
                contained: {
                  short: 'c',
                  info:  "No shared dependencies, copy instead of symlinks",
                },
              },
              variables: {
                tag: {
                  info: "Package version's tag (e.g: latest)",
                },
                version: {
                  info: "Package version",
                },
              },
            },
            version: {
              alias:     'v',
              info:      "Returns application's version",
              action:    "Log.output.puts App.version",
              arguments: \%w(application),
              inherit:   \%w(group prefix),
            },
          },
        },
        list: {
          alias:   'l',
          info:    "List all applications, packages and sources",
          action:  "List.all",
          inherit: \%w(group prefix source_name source_path),
        },
        package: {
          alias:     'p',
          info:      "Manage built packages",
          inherit:   \%w(config no_confirm prefix source_name source_path),
          variables: {
            tag: {
              info: "Package version's tag (e.g: latest)",
            },
            version: {
              info: "Package version",
            },
          },
          commands: {
            build: {
              alias:     'b',
              info:      "Build a new a package",
              action:    "Pkg.build",
              arguments: \%w(package custom_vars...),
              inherit:   \%w(config no_confirm prefix source_name source_path tag version),
            },
            clean: {
              alias:   'C',
              info:    "Clean unused built packages by the applications",
              action:  "Pkg.clean_unused_packages",
              inherit: \%w(no_confirm prefix source_name),
            },
            delete: {
              alias:     'd',
              info:      "Delete a built package",
              action:    "Pkg.delete",
              arguments: \%w(package),
              inherit:   \%w(no_confirm prefix source_name version),
            },
            info: {
              info:      "Get information of a package - `.` for the whole document.",
              action:    "Log.output.puts Pkg.info",
              arguments: \%w(package path),
              inherit:   \%w(prefix source_name),
            },
            list: {
              alias:   'l',
              info:    "List packages",
              action:  "List.pkg",
              inherit: \%w(prefix),
            },
          },
        },
        service: {
          alias:    'S',
          info:     "Manage application services",
          inherit:  \%w(debug prefix),
          commands: {
            boot: {
              info:      "Auto-start the service at boot",
              action:    "Service.boot",
              arguments: \%w(service state),
            },
            reload: {
              info:      "Reload the service",
              action:    "Service.new().reload || exit 1",
              arguments: \%w(service),
            },
            restart: {
              info:      "Restart the service",
              action:    "Service.new().restart || exit 1",
              arguments: \%w(service),
            },
            start: {
              info:      "Start the service",
              action:    "Service.new().start || exit 1",
              arguments: \%w(service),
            },
            status: {
              info:      "Status for specified services or all services if none set",
              action:    "Service.status",
              arguments: \%w(services...),
              inherit:   \%w(prefix),
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
              arguments: \%w(service),
              action:    "Service.new().stop || exit 1",
            },
          },
        },
        source: {
          alias:    's',
          info:     "Manage packages sources",
          inherit:   \%w(config no_confirm prefix source_name source_path),
          commands: {
            list: {
              alias:   'l',
              info:    "List source packages",
              action:  "List.src",
              inherit: \%w(prefix),
            },
            info: {
              info:      "Get information of a source package - `.` for the whole document",
              action:    "Log.output.puts Src.info",
              arguments: \%w(package path),
              inherit:   \%w(prefix source_name),
            },
            update: {
              alias:   'u',
              info:    "Check for packages source updates. `-y` to force update",
              action:  "Src.update",
              inherit: \%w(config no_confirm prefix source_name source_path),
            },
          },
        },
        version: {
          alias:  'v',
          info:   "Version with general system information",
          action: "version",
        },
        {{**additional_commands}}
      }
    )
  rescue ex : Help
    Log.output.puts ex
  rescue ex : ArgumentRequired | UnknownCommand | UnknownOption | UnknownVariable
    abort ex
  rescue ex
    if ENV["DEBUG"]?
      ex.inspect_with_backtrace Log.error
    else
      Log.error ex
    end
    exit 1
  end
  DPPM::CLI.internal_run
  end

  def version(**args)
    Log.output << "DPPM version: " << DPPM.version << '\n'
    Log.output << "DPPM build commit: " << DPPM.build_commit << '\n'
    Log.output << "DPPM build date: " << DPPM.build_date << '\n'
    Host.vars.each do |variable, value|
      Log.output << variable << ": " << value << '\n'
    end
  end

  def info(any : CON::Any, path : String) : CON::Any?
    case path
    when "." then any
    else          Config::CON.new(any).get path
    end
  end

  def install_dppm(no_confirm, config, prefix, group, source_name, source_path)
    root_prefix = Prefix.new prefix, group: group, source_name: source_name, source_path: source_path

    if root_prefix.dppm.exists?
      Log.info "DPPM already installed", root_prefix.path.to_s
      return root_prefix
    end
    root_prefix.create

    begin
      root_prefix.update

      dppm_package = root_prefix.new_pkg "dppm", DPPM.version
      dppm_package.copy_src_to_path

      Dir.mkdir dppm_package.app_path.to_s
      Dir.mkdir (dppm_package.app_path / "bin").to_s
      dppm_bin_path = dppm_package.app_path / "bin/dppm"
      FileUtils.cp PROGRAM_NAME, dppm_bin_path.to_s
      app = dppm_package.new_app "dppm"

      app.add(
        vars: {"uid" => Process.uid.to_s, "gid" => Process.gid.to_s},
        shared: true,
        confirmation: !no_confirm
      ) do
        no_confirm || CLI.confirm_prompt { raise "DPPM installation canceled." }
      end
    rescue ex
      root_prefix.delete
      raise Exception.new "DPPM installation failed, #{root_prefix.path} deleted", ex
    end
    dppm_package.create_global_bin_symlinks(force: true) if Process.root?
    Log.info "DPPM installation complete", "you can now manage applications with the `#{Process.root? ? "dppm" : dppm_bin_path}` command"
    File.delete PROGRAM_NAME
  end

  def uninstall_dppm(no_confirm, config, prefix, group, source_name, source_path)
    root_prefix = Prefix.new prefix, group: group, source_name: source_name, source_path: source_path

    raise "DPPM not installed in #{root_prefix.path}" if !root_prefix.dppm.exists?
    raise "DPPM path not removable - root permission needed #{root_prefix.path}" if !File.writable? root_prefix.path.to_s

    # Delete each installed app
    root_prefix.each_app do |app|
      app.delete(confirmation: !no_confirm, preserve_database: false, keep_user_group: false) do
        if no_confirm || CLI.confirm_prompt
          app.pkg.delete_global_bin_symlinks
          true
        end
      end
    end

    if (apps = Dir.children(root_prefix.app.to_s).join ", ").empty?
      root_prefix.delete
      Log.info "DPPM uninstallation complete", root_prefix.path.to_s
    else
      Log.warn "DPPM uninstallation not complete, there are remaining applications", apps
    end
  end

  def confirm_prompt(&block)
    Log.output.puts "\nContinue? [N/y]"
    case gets
    when "Y", "y" then true
    else               yield
    end
  end

  def confirm_prompt
    confirm_prompt { abort "cancelled." }
  end
end
