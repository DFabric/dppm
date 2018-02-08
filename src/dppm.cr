# stdlibs
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

require "./dppm/**"

HOST  = Localhost.new
CACHE = "/tmp/dppm-package-sources/"

Command.new.run
