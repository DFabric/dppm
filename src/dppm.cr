# stdlibs
require "colorize"
require "file_utils"
require "http/client"
require "openssl"
require "semantic_version"
require "uuid"
require "yaml"

# Third party libraries
require "exec"
require "semantic_compare"

require "./dppm/**"

CLI.run
