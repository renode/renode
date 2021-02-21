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

Using the Linux portable release
++++++++++++++++++++++++++++++++

If you are a Linux user, the easiest way to use Renode is to download the latest `linux-portable` from `the releases section <https://github.com/renode/renode/releases/latest>`_ and unpack it using::

   mkdir renode_portable
   tar xf  renode-*.linux-portable.tar.gz -C renode_portable --strip-components=1

To use it from any location enter the created directory and add it to the system path::

   cd renode_portable
   export PATH="`pwd`:$PATH"

Follow the 'Additional Prerequisites' section if you wish to use Robot framework for testing.
Otherwise you are ready to go to the 'Running Renode' section.

Please note that on the fly compilation of ``*.cs`` files is not supported in the portable version.

Installing dependencies
+++++++++++++++++++++++

Mono/.NET
~~~~~~~~~

Renode requires Mono >= 5.20 (Linux, macOS) or .NET >= 4.7 (Windows).

.. csv-table::
   :delim: |

   **Linux** | Install the ``mono-complete`` package as per the installation instructions for various Linux distributions which can be found on `the Mono project website <https://www.mono-project.com/download/stable/#download-lin>`_.
   **macOS** | On macOS, the Mono package can be downloaded directly from `the Mono project website <https://download.mono-project.com/archive/mdk-latest-stable.pkg>`_.
   **Windows** | On Windows 7, download and install `.NET Framework 4.7 <https://www.microsoft.com/net/download/dotnet-framework-runtime>`_. Windows 10 ships with .NET by default, so no action is required there.

Other dependencies (Linux only)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On Ubuntu 20.04, you can install the remaining dependencies with the following command::

   sudo apt-get install policykit-1 libgtk2.0-0 screen uml-utilities gtk-sharp2 libc6-dev gcc python3 python3-pip libzmq5

If you are running a different distribution, you will need to install an analogous list of packages using your package manager; note that the package names may differ slightly.

Installing from packages
++++++++++++++++++++++++

Go to `the releases section <https://github.com/renode/renode/releases/latest>`_ of this repository and download the appropriate package for your system.

.. csv-table::
   :delim: |

   **Linux** | Install Renode as normal with your preferred package manager using the provided ``*.deb``, ``*.rpm`` or ``*.pkg.tar.xz`` packages.
   **macOS** | Use the provided ``*.dmg`` as normal. Additionally, to be able to run Renode from the command line on macOS, create an appropriate alias. If you're using Bash, you can do it by adding ``alias renode='mono /Applications/Renode.app/Contents/MacOS/bin/Renode.exe'`` to your ``.bashrc`` file.
   **Windows** | Install Renode from the provided ``*.msi`` file. The installer will allow you to add icons to your Desktop and/or Start Menu and an entry to your PATH.

Additional prerequisites (for Robot framework testing)
++++++++++++++++++++++++++++++++++++++++++++++++++++++

To write and run test cases, Renode integrates with the Robot testing framework.
This requires you to install Python 3 (on Windows, you will also need Cygwin - see `the advanced installation instructions <https://renode.readthedocs.io/en/latest/advanced/building_from_sources.html#windows>`_) with ``pip`` (note that the relevant package may be called ``python-pip`` or ``python3-pip`` on Linux).

Once you have Python 3 and ``pip``, install some additional modules::

    python3 -m pip install -r tests/requirements.txt

Building from source (advanced)
+++++++++++++++++++++++++++++++

For information on building Renode from source see `the documentation <https://renode.readthedocs.io/en/latest/advanced/building_from_sources.html>`_.

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
   -v            prints the version number
   -h            help & usage

On Windows systems Renode can be run by starting Renode.exe with a similar set of optional flags.

Running Renode in a Docker container
------------------------------------

If you want to run Renode in Docker you can use a prebuilt image available on Docker Hub.

To start it in interactive mode on Linux, assuming you have installed Docker on your system, run::

   docker run -ti -e DISPLAY -v $XAUTHORITY:/home/developer/.Xauthority --net=host antmicro/renode

This should display the Renode Monitor window.
Alternatively, you can provide your custom command at the end of the above line.

To run the image in console mode without X server passthrough, run::

   docker run -ti antmicro/renode bash

To mount your own directories, add more ``-v`` switches to the command.

The Docker image contains sources of Renode in the ``~/renode`` directory.
To compile and use a custom version of your choice you can run::

   cd renode
   git fetch
   git checkout <commit>
   ./build.sh -p
   sudo apt install -y ./output/packages/renode*deb

For more information and the underlying Dockerfile, visit the `repository on GitHub <https://github.com/renode/renode-docker>`_.

Documentation
-------------

Documentation is available on `Read the Docs <https://renode.readthedocs.io>`_.

License & contributions
-----------------------

Renode is released under the permissive MIT license.
For details, see the `<LICENSE>`_ file.

We’re happy to accept bug reports, feature requests and contributions via GitHub pull requests / issues.
For details, see the `<CONTRIBUTING.rst>`_ file.

Commercial support
------------------

Commercial support for Renode is provided by `Antmicro <https://antmicro.com>`_, a company specializing in helping its clients to adopt new embedded technologies and modern development methodologies.

Antmicro created and maintains the Renode framework and related tooling, and is happy to provide services such as adding new platforms, integrations, plugins and tools.

To inquire about our services, contact us at support@renode.io.
