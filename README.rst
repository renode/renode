Renode
======

What is Renode?
---------------

Renode was created by Antmicro as a virtual development tool for multinode embedded networks (both wired and wireless) and is intended to enable a scalable workflow for creating effective, tested and secure IoT systems.

With Renode, developing, testing, debugging and simulating unmodified software for IoT devices is fast, cost-effective and reliable.

Supported architectures include:

* ARM Cortex-A and Cortex-M
* x86
* RISC-V
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

Installing dependecies for Linux and macOS
..........................................

Renode requires Mono >= 5.0.
To install it on Linux, use::

   sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
   echo "deb http://download.mono-project.com/repo/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list
   sudo apt-get update
   sudo apt-get install mono-complete policykit-1 libgtk2.0-0 screen uml-utilities gtk-sharp2 libc6-dev

.. note::

    Modify the distribution name according to your setup.

On macOS, Mono can be downloaded from `the official Mono project website <https://download.mono-project.com/archive/mdk-latest-stable.pkg>`_.

Getting .NET (Windows 7 only)
.............................

On Windows 7, download and install `.NET Framework 4.7 <https://www.microsoft.com/net/download/dotnet-framework-runtime>`_.

Installing from packages
........................

With Mono installed as described above, use the ``*.deb``, ``*.rpm``, ``*.pkg.tar.xz`` files for Linux and ``*.dmg`` files for macOS from `the releases section <https://github.com/renode/renode/releases/latest>`_ as normal to install Renode using your package manager.

To be able to run Renode from the command line on macOS, create an appropriate alias.
If you're using Bash, you can do it by adding ``alias renode="mono /Applications/Renode.app/Contents/MacOS/bin/Renode.exe"`` to your ``.bashrc`` file.

For Windows, just unzip the ``*.zip`` package in the directory of your choice.
Add the location of the ``bin`` subdirectory to the PATH variable to have the ``renode`` command available from the command line.

Additional prerequisites
........................

To run tests you must install Python 2.7 with additional modules.
For detailed info, see `the documentation <http://renode.readthedocs.io/en/latest/advanced/building_from_sources.html#installing-python-modules>`_.

Building from source (advanced)
...............................

For information on building Renode from source see `the documentation <http://renode.readthedocs.io/en/latest/advanced/building_from_sources.html>`_.

Running Renode
--------------

If you followed the instructions on installing from a package above, you should have a system-wide ``renode`` command that you can use to run the tool::

   renode [flags] [file]

If you built it from source, navigate to the relevant directory and use::

   ./renode [flags] [file]

The optional ``[file]`` argument allows you to provide the path to a script to be run on startup.

The script allows several optional flags, most useful of which are presented below::

   -d            debug mode (requires prior build in debug configuration) - only available when built from source
   -e COMMAND    execute command on startup (does not allow the [file] argument)
   -p            remove steering codes (e.g., colours) from output
   -P PORT       listen on a port for monitor commands instead of opening a window
   -h            help & usage

On Windows systems Renode can be run by starting Renode.exe with a similar set of optional flags.

Documentation
-------------

Documentation is available on `Read the Docs <http://renode.readthedocs.io>`_.

License & contributions
-----------------------

Renode is released under the permissive MIT license.
For details, see the `<LICENSE>`_ file.

We’re happy to accept bug reports, feature requests and contributions via GitHub pull requests / issues.
For details, see the `<CONTRIBUTING.rst>`_ file.

Commercial support
------------------

Commercial support for Renode is provided by `Antmicro <http://antmicro.com>`_, a company specializing in helping its clients to adopt new embedded technologies and modern development methodologies.

Antmicro created and maintains the Renode framework and related tooling, and is happy to provide services such as adding new platforms, integrations, plugins and tools.

To inquire about our services, contact us at support@renode.io.

