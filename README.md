![DP logo](https://avatars.githubusercontent.com/u/19499073)

[![Gitter](https://img.shields.io/badge/chat-on_gitter-red.svg?style=flat-square)](https://gitter.im/DFabric/dppm)
[![ISC](https://img.shields.io/badge/License-ISC-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ISC_license)

# DPPM

*The DPlatform's Package Manager*

## Features

- choice among [dozens of applications](https://github.com/DFabric/packages-source)
- easy install, backup and modification of configurations
- support a wide range of systems (UN*Xes, x86, ARM) - distribution agnostic
- can use systemd or OpenRC for system services
- independent of your system's package manager - self-contained, statically linked binaries
- standalone installations bundled with all dependencies - DDPM can be safely removed

## Install

Supported architectures are `x86-64` and `arm64` (thanks to [@jirutka](https://github.com/jirutka)).

32-bit architectures are partially supported, but discouraged since nowadays more and more applications are designed for 64-bit, particularly databases ([TiDB](https://github.com/pingcap/tidb/issues/5224), [MongoDB](https://www.mongodb.com/blog/post/32-bit-limitations)...)

For Rapberry Pi 3, a 64-bit OS like [Armbian](https://www.armbian.com/) is recommended, and needed to run DPPM, instead of a 32-bit Raspbian.

Still, [an issue is open](https://github.com/crystal-lang/crystal/issues/5467) for `armhf`.

## Automatic

Download `dppm` with the helper:

`sh -c "APP=dppm-static $(wget -qO- https://raw.githubusercontent.com/DFabric/apps-static/master/helper.sh)"`

The binary is `bin/dppm` on the directory. Place it wherever you want (e.g. `/usr/local/bin`)

`wget -qO-` can be replaced by `curl -s`

## Manual

Get [the pre-compiled binary](https://bitbucket.org/dfabric/packages/downloads/) called `dppm-static_*`, and extract it.

## Usage

To show the help:

`dppm --help`

To list [available packages](https://github.com/DFabric/package-sources) (applications, built and available packages):

`dppm m list`

A typical installation can be:

```sh
# add a new application to the system
dppm m app add [application]

# start the service and  auto start the service at boot
dppm service start [application]
dppm service boot [application] true
```

If not specified, an user, group and application name will be created.

Note that `add` will `build` the missing required packages.

Root execution is needed to add a system service (systemd or OpenRC)

To follow last application logs:

`dppm logs -f [application]`

## How to build

You will need a [Crystal](https://crystal-lang.org) development environment

You can either [install it](https://crystal-lang.org/docs/installation) or use a [Docker image](https://hub.docker.com/r/jrei/crystal-alpine)

Install dependencies:

`shards install`

Build a `dppm` executable:

`crystal build src/dppm.cr`

Run it

`./dppm --help`

For more informations, see the [official docs](https://crystal-lang.org/docs/using_the_compiler/)

## License                                                                                                 

Copyright (c) 2018 Julien Reichardt - ISC License
