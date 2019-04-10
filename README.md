![DP logo](https://avatars.githubusercontent.com/u/19499073)

[![Gitter](https://img.shields.io/badge/chat-on_gitter-red.svg?style=flat-square)](https://gitter.im/DFabric/dppm)
[![ISC](https://img.shields.io/badge/License-ISC-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ISC_license)

# DPPM

Dedicated Platform Package Manager - an easy way to install and manage server applications.

## Features

- Choice among [dozens of applications](https://github.com/DFabric/packages-source)
- Unified interface for easy install, backup and modification of configurations
- Support a wide range of systems (UN*Xes, x86, ARM) - distribution agnostic
- Can use systemd or OpenRC system services with dedicated users/groups
- Independent of the OS package manager - self-contained, statically linked binaries
- Standalone installations bundled with all dependencies - DPPM can be safely removed
- Compatible with manual system administration (like editions "by hand" on the file system)

## Install

### 1. Get the `dppm` binary

There are 3 methods:

- Automatic

Download `dppm` with the helper:

`sh -c "APP=dppm-static $(wget -qO- https://raw.githubusercontent.com/DFabric/apps-static/master/helper.sh)"`

(`wget -qO-` can be replaced by `curl -s`)

The binary is `bin/dppm` in the directory.

- Manual

Get [the pre-compiled binary](https://bintray.com/dfabric/apps-static/builds#files) called `dppm-static_*`, and extract it.

- Clone the repository and compile the project

See the `Development` section

### 2. Run the installation command

`sudo bin/dppm app install`

You don't *need* to install it as root, but no system services nor dedicated users will be available. You will have to rely on `sudo dppm app exec`

## Usage

To show the help:

`dppm --help`

To list [available packages](https://github.com/DFabric/package-sources) (applications, built and available packages):

`dppm list`

A typical installation can be:

```sh
# add a new application to the system
sudo dppm app add [application]

# start the service and auto start the service at boot
sudo dppm service start [application]
sudo dppm service boot [application] true
```

If not specified, an user, group and application name will be created.

Note that `add` will `build` the missing required packages.

Root execution is needed to add a system service (systemd or OpenRC)

To show the services status:

`dppm service status`

To follow last application logs:

`sudo dppm logs [application] output`

## Uninstall

`sudo dppm app uninstall`

## Supported environments

Supported architectures are `x86-64` and `arm64` (thanks to [@jirutka](https://github.com/jirutka)).

32-bit architectures are partially supported, but discouraged since nowadays more and more applications are designed for 64-bit, particularly databases ([TiDB](https://github.com/pingcap/tidb/issues/5224), [MongoDB](https://www.mongodb.com/blog/post/32-bit-limitations)...)

For Rapberry Pi 3, a 64-bit OS like [Armbian](https://www.armbian.com/) is recommended, and needed to run DPPM, instead of a 32-bit Raspbian.

Still, [an issue is open](https://github.com/crystal-lang/crystal/issues/5467) for `armhf`.

## Development

You will need a [Crystal](https://crystal-lang.org) development environment

You can either [install it](https://crystal-lang.org/docs/installation) or use a [Docker image](https://hub.docker.com/r/jrei/crystal-alpine)

You may also find useful this variables `config=./config.con` and `source=../packages-source`

### How to build

Install dependencies and build `dppm`:

`shards build`

Run it

`bin/dppm --help`

For more informations, see the [official docs](https://crystal-lang.org/docs/using_the_compiler/)

### Run tests

Integration tests are stateful and need to be runned all in a batch sequentially.

To run them: `crystal spec spec/integration_spec.cr`

Other tests are stateless and can be runned independently to each other

To run all tests: `crystal spec`

## License                                                                                                 

Copyright (c) 2018-2019 Julien Reichardt - ISC License
