Renode
======

What is Renode?
---------------

Renode was created by Antmicro as a virtual development tool for multinode embedded networks (both wired and wireless) and is intended to enable a scalable workflow for creating effective, tested and secure IoT systems.

With Renode, developing, testing, debugging and simulating unmodified software for IoT devices is fast, cost-effective and reliable.

Supported architectures include:

* ARM Cortex-A and Cortex-M
* x86
* RISC-V (coming soon!)
* SPARC
* PowerPC

Why use Renode?
---------------

Renode was created based on many years of experience with the development of software for embedded systems - both for gateways, on-board computers as well as sensor nodes and microcontrollers.

Testing and developing physical embedded systems is difficult due to poor reproducibility and lack of insight into the current state of a system, especially in multinode scenarios.

Renode addresses this issue by letting you run unmodified binaries, identical to the ones that you would normally flash onto their target hardware, on a virtual board or system of boards.

One important aspect of the tool is that it simulates not only CPUs but entire SoCs (including e.g. heterogeneous multicore SoCs and various peripherals) as well as the wired or wireless connections between them, which allows users to address complex scenarios and test real production software.

Installation
------------

=============
From packages
=============

``*.deb``, ``*.rpm``, ``*.pkg.tar.xz`` files for Linux and ``*.dmg`` files for macOS are provided in `the releases section <https://github.com/renode/renode/releases/latest>`_ - use them as normal to install Renode using your package manager.

For macOS, you need to install the Mono framework manually - consult the `Mac`_ section for instructions.

For Windows, just unzip the ``*.zip`` package in the directory of your choice.

Once you install Renode, you can skip directly to `Running Renode`_.

===============================
Building from source (advanced)
===============================

Prerequisites
+++++++++++++

Linux
~~~~~

The following instructions have been tested on Ubuntu 16.04, however there should not be any major issues preventing you from using other (especially Debian-based) distributions as well.

Renode requires Mono >= 5.0 and several other packages.
To install them, use::

   sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
   echo "deb http://download.mono-project.com/repo/debian wheezy main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list
   sudo apt-get update
   sudo apt-get install git mono-complete automake autoconf libtool g++ realpath \
                        gksu libgtk2.0-dev dialog screen uml-utilities gtk-sharp2

Mac
~~~

Renode requires the Mono framework, which can be downloaded from `the official Mono project website <https://download.mono-project.com/archive/mdk-latest-stable.pkg>`_.

To install the remaining prerequisites of Renode, use::

   brew install binutils gnu-sed coreutils homebrew/versions/gcc49 dialog

.. note::

   This requires `homebrew <http://brew.sh/>`_ to be installed in your system.

Windows
~~~~~~~

Prior to repository clone, git has to be configured appropriately::

   git config --global core.autocrlf false
   git config --global core.symlinks true

The prerequisites for Renode on Windows are as follows:

* MSBuild 15.0
* .NET versions 4.0, 4.5, 4.7
* Cygwin (with module: openssh, dialog)
* MinGW (with module: pthreads)
* Python 2.7 (with modules: robotframework, netifaces, requests)
* Gtk# 2.12.30 (this precise version is required, downloadable from `Xamarin website <http://download.xamarin.com/GTKforWindows/Windows/gtk-sharp-2.12.30.msi>`_
* Git (either natively on Windows or as a Cygwin module)

The building process described further on in this document may be only executed in Cygwin shell.
To be able to use all of the prerequisites, the user has to configure Cygwin's PATH variable to include the following directories:

* MSBuild
* Python
* MinGW
* Gtk#
* Git (if installed as a Windows application)

It is required to use Python installed as a native Windows application, not as a Cygwin module.
If there are multiple Python versions installed on the machine used for developing Renode, Cygwin will use the first instance found in its PATH.

Downloading the source code
+++++++++++++++++++++++++++

Renode’s source code is available from GitHub::

   git clone https://github.com/renode/renode.git

Submodules will be automatically initialised and downloaded during the build process, so you do not need to do it at this point.

Building Renode
+++++++++++++++

To build Renode, run::

   ./build.sh

There are some optional flags you can use::

   -c          clean instead of building
   -d          build in debug configuration
   -v          verbose mode
   -p          build binary packages (requires some additional dependencies)

You may also build ``Renode.sln`` from your IDE (like MonoDevelop), but the ``build.sh`` script has to be run at least once.

Running Renode
--------------

If you installed from a package, you should have a system-wide ``renode`` command that you can use to run the tool::

   renode [flags] [file]

If you built it from source, navigate to the relevant directory and use::

   ./renode [flags] [file]

The optional ``[file]`` argument allows the user to provide the path to a script to be run on startup.

The script allows several optional flags, most useful of which are presented below::

   -d            debug mode (requires prior build in debug configuration) - only available when built from source
   -e COMMAND    execute command on startup (does not allow the [file] argument)
   -p            remove steering codes (e.g., colours) from output
   -P PORT       listen on a port for monitor commands instead of opening a window
   -h            help & usage

On Windows systems Renode can be run by starting Renode.exe with a similar set of optional flags.

Documentation
-------------

Documentation will be available soon.

License & contributions
-----------------------

Renode is released under the permissive MIT license.
For details, see the `LICENSE <LICENSE>`_ file.

We’re happy to accept bug reports, feature requests and contributions via GitHub pull requests / issues.
For details, see the `CONTRIBUTING.rst <CONTRIBUTING.rst>`_ file.

Commercial support
------------------

Commercial support for Renode is provided by `Antmicro <http://antmicro.com>`_, a company specializing in helping its clients to adopt new embedded technologies and modern development methodologies.

Antmicro created and maintain the Renode framework and related tooling, and are happy to provide services such as adding new platforms, integrations, plugins and tools.

To inquire about our services, contact us at support@renode.io.

