# DPPM

*The DPlatform's Package Manager*

# Features

- easy install, modification and backup of applications
- support a wide range of systems (UN*Xes, x86, ARM). Distribution agnostic
- can use systemd or OpenRC for system services
- independent of your system package manager

# Install

For now only the x86-64 architecture is available. [An issue is open](https://github.com/crystal-lang/crystal/issues/5467) to support `armhf` and `aarch64`.

## Automatic

Get the helper:

`wget https://raw.githubusercontent.com/DFabric/apps-static/master/helper.sh -O /tmp/helper.sh`

or

`curl -SL https://raw.githubusercontent.com/DFabric/apps-static/master/helper.sh -o /tmp/helper.sh`

Download `dppm`:

`sh /tmp/helper.sh dppm-static`

The binary is `bin/dppm` on the directory. Place it wherever you want (e.g. `/usr/local/bin`)

## Manual

Get [the pre-compiled binary](https://bitbucket.org/dfabric/packages/downloads/) called `dppm-static_*`, and extract it.

# Use

To show the help:

`dppm --help`

To list available packages (application and libraries):

`dppm list`

A typical installation can be:

```sh
dppm install [application] prefix=/opt # install a new application in /opt
dppm service [application] run true    # start the service
dppm service [application] boot true   # auto start the service at boot
```

Note that `install` will `build` the package, and then `add` it to the system.

Root execution is needed to add a system service (systemd or OpenRC)

# How to build

This following command will build a `dppm` executable:

`crystal build src/dppm.cr -o dppm`

And run it

`./dppm --help`

For more informations, see the [offcial docs](https://crystal-lang.org/docs/using_the_compiler/)

# License                                                                                                 

Copyright (c) 2018 Julien Reichardt - ISC License
