![DP logo](https://avatars.githubusercontent.com/u/19499073)

[![Gitter](https://img.shields.io/badge/chat-on_gitter-red.svg?style=flat-square)](https://gitter.im/DFabric/dppm)
[![ISC](https://img.shields.io/badge/License-ISC-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ISC_license)

# DPPM

*The DPlatform's Package Manager*

# Features

- easy install, modification and backup of the applications
- support a wide range of systems (UN*Xes, x86, ARM) - distribution agnostic
- can use systemd or OpenRC for system services
- independent of your system's package manager

# Install

For now only the x86-64 architecture is available. [An issue is open](https://github.com/crystal-lang/crystal/issues/5467) to support `armhf` and `arm64`.

Hopefully there are recent progress on both architectures, DPPM will be available on soon! The `arm64` support is now merged.

## Automatic

Download `dppm` with the helper:

`sh -c "APP=dppm-static $(wget -qO- https://raw.githubusercontent.com/DFabric/apps-static/master/helper.sh)"`

The binary is `bin/dppm` on the directory. Place it wherever you want (e.g. `/usr/local/bin`)

`wget -qO-` can be replaced by `curl -s`

## Manual

Get [the pre-compiled binary](https://bitbucket.org/dfabric/packages/downloads/) called `dppm-static_*`, and extract it.

# Usage

To show the help:

`dppm --help`

To list [available packages](https://github.com/DFabric/package-sources) (applications and libraries):

`dppm list`

A typical installation can be:

```sh
# `opt` directory with the `myapp` owner
dppm add [application] prefix=/opt owner=myapp     # add a new application to the system
dppm service [application] run true                # start the service
dppm service [application] boot true               # auto start the service at boot
```

The user and group used by the application here is `myapp`. [Read more about security recommendations](https://github.com/DFabric/docs/blob/master/security/owner.md)

Note that `add` will `build` the missing required packages.

Root execution is needed to add a system service (systemd or OpenRC)

# How to build

Intall dependencies:

`shards install`

Build a `dppm` executable:

`crystal build src/dppm.cr`

Run it

`./dppm --help`

For more informations, see the [official docs](https://crystal-lang.org/docs/using_the_compiler/)

# License                                                                                                 

Copyright (c) 2018 Julien Reichardt - ISC License
