# DPPM

*The DPlatform's Package Manager*

# Features

- easy install, modification and backup of applications
- support a wide range of systems (UN*Xes, x86, ARM). Distribution agnostic
- can use systemd or OpenRC for system services
- independent of your system package manager

# Use

To show the help:

`dppm --help`

To list available packages (application and libraries):

`dppm list`

A typical installation can be:

```sh
dppm install [application] # install a new application:
dppm service [application] run true # start it
dppm service [application] boot true # auto start the service at boot
```

Note that `install` will `build` the package, and then `add` it to the system.

Root execution is needed to add a system service (systemd/OpenRC)

Prebuilt binaries will come soon.

# How to build

This following command will build a `dppm` executable:

`crystal build src/dppm.cr -o dppm`

And run it

`./dppm --help`

For more informations, see the [offcial docs](https://crystal-lang.org/docs/using_the_compiler/)

# License                                                                                                 

Copyright (c) 2018 Julien Reichardt - ISC License
