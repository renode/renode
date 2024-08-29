# Renode

Copyright (c) 2010-2024 [Antmicro](https://www.antmicro.com)

[![View on Antmicro Open Source Portal](https://img.shields.io/badge/View%20on-Antmicro%20Open%20Source%20Portal-332d37?style=flat-square)](https://opensource.antmicro.com/projects/renode)

## What is Renode?

Renode was created by Antmicro as a virtual development tool for multi-node embedded networks (both wired and wireless) and is intended to enable a scalable workflow for creating effective, tested and secure IoT systems.

With Renode, developing, testing, debugging and simulating unmodified software for IoT devices is fast, cost-effective and reliable.

Supported architectures include:

* ARMv7 and ARMv8 Cortex-A, Cortex-R and Cortex-M
* x86 and x86_64
* RISC-V
* SPARC
* POWER
* Xtensa

## Why use Renode?

Renode was created based on many years of experience with the development of software for embedded systems - both for gateways, on-board computers, as well as sensor nodes and microcontrollers.

Testing and developing physical embedded systems is difficult due to poor reproducibility and lack of insight into the current state of a system, especially in multi-node scenarios.

Renode addresses this issue by letting you run unmodified binaries identical to the ones you would normally flash onto their target hardware on a virtual board or system of boards.

One important aspect of the tool is that it simulates not only CPUs but entire SoCs (e.g., heterogeneous multicore SoCs and various peripherals) as well as the wired or wireless connections between them, allowing users to address complex scenarios and test real production software.

## Installation

### Available builds and releases

#### Nightly builds

Nightly builds of Renode for all systems are available at [builds.renode.io](https://builds.renode.io).

The latest builds are always available as `renode-latest.*` packages.
The following packages formats are available:
* [`renode-latest.linux-portable-dotnet.tar.gz`](https://builds.renode.io/renode-latest.linux-portable-dotnet.tar.gz) -  portable Linux package, embeds dotnet runtime
* [`renode-latest.linux-portable.tar.gz`](https://builds.renode.io/renode-latest.linux-portable.tar.gz) - portable Linux package, embeds Mono runtime
* [`renode-latest.linux-dotnet.tar.gz`](https://builds.renode.io/renode-latest.linux-dotnet.tar.gz) - Linux prebuilt archive, requires dotnet installed on host
* [`renode-latest.pkg.tar.xz`](https://builds.renode.io/renode-latest.pkg.tar.xz) - Arch Linux package
* [`renode-latest.x86_64.rpm`](https://builds.renode.io/renode-latest.x86_64.rpm) - Red Hat / Fedora package
* [`renode-latest.deb`](https://builds.renode.io/renode-latest.deb) - Debian-based distribution package
* [`renode-latest.dmg`](https://builds.renode.io/renode-latest.dmg) - macOS package
* [`renode-latest.zip`](https://builds.renode.io/renode-latest.zip) - Windows portable package, without installer
* [`renode-latest.msi`](https://builds.renode.io/renode-latest.msi) - Windows installer
* [`renode-latest.tar.xz`](https://builds.renode.io/renode-latest.tar.xz) - Renode sources

#### Stable releases

Stable, numbered releases and their release notes are available in the [Releases section](https://github.com/renode/renode/releases) on GitHub.

### Using the Linux portable release

If you are a Linux user, the easiest way to use Renode is to download the latest `linux-portable` from [the releases section](https://github.com/renode/renode/releases/latest) and unpack it using:

```
mkdir renode_portable
wget https://builds.renode.io/renode-latest.linux-portable.tar.gz
tar xf  renode-latest.linux-portable.tar.gz -C renode_portable --strip-components=1
```

To use it from any location, enter the created directory and add it to the system path:

```
cd renode_portable
export PATH="`pwd`:$PATH"
```

Please note that the portable package requires GTK2 to be available on the host to run with the UI enabled.

Follow the [Additional Prerequisites](#additional-prerequisites-for-robot-framework-testing) section if you wish to use Robot Framework for testing.
Otherwise, proceed to the 'Running Renode' section.

### Installing dependencies

#### Mono/dotnet

Renode requires Mono >= 5.20 (Linux, macOS) or .NET Framework >= 4.7 (Windows).
On all systems, you can also use dotnet >= 6.0.

##### Linux

To install dotnet on Linux, follow [the official installation guide](https://learn.microsoft.com/en-us/dotnet/core/install/linux).

Alternatively, install the `mono-complete` package as per the installation instructions for various Linux distributions you can find on [the Mono project website](https://www.mono-project.com/download/stable/#download-lin).

##### macOS

To install dotnet on macOS, follow [the official installation guide](https://learn.microsoft.com/en-us/dotnet/core/install/macos).

Alternatively, for Mono-based setups, you can download the Mono package directly from [the Mono project website](https://download.mono-project.com/archive/mdk-latest-stable.pkg).

##### Windows

To install modern dotnet (as opposed to .NET Framework) on Windows, follow [the official installation guide](https://learn.microsoft.com/en-us/dotnet/core/install/windows).
The **.NET SDK** includes runtime, so you will be able to build and run Renode.

#### Other dependencies (Linux only)

On Ubuntu 20.04, you can install the remaining dependencies with the following command:

```
sudo apt-get install policykit-1 libgtk2.0-0 screen uml-utilities gtk-sharp2 libc6-dev libicu-dev gcc python3 python3-pip
```

If you are running a different distribution, you will need to install an analogous list of packages using your package manager; note that the package names may differ slightly.

### Installing from packages

Go to [the releases section](https://github.com/renode/renode/releases/latest) of this repository and download an appropriate package for your system.

#### Linux

Install Renode with your preferred package manager using the provided `*.deb`, `*.rpm` or `*.pkg.tar.xz` packages.

#### macOS

Use the provided `*.dmg` as normal. 
Additionally, to use Renode from the command line on macOS, create appropriate aliases by adding `alias renode='mono /Applications/Renode.app/Contents/MacOS/bin/Renode.exe'` and `alias renode-test='/Applications/Renode.app/Contents/MacOS/tests/renode-test'` to your `.bashrc` or `.zshrc` file, depending on the shell you're using.

#### Windows

Install Renode from the provided `*.msi` file. The installer will allow you to add icons to your Desktop and/or Start Menu and an entry to your PATH.

### Additional prerequisites

#### Robot Framework testing

To write and run test cases, Renode integrates with the Robot testing framework.
This requires you to install Python 3 (on Windows, you will also need Cygwin - see [the advanced installation instructions](https://renode.readthedocs.io/en/latest/advanced/building_from_sources.html#windows)) with `pip` (note that the relevant package may be called `python-pip` or `python3-pip` on Linux).

Once you have Python 3 and `pip`, install additional modules:

```
python3 -m pip install -r tests/requirements.txt
```

#### Other tools

Additionally, each of the tools in the `/tools` subdirectory may contain a `requirements.txt` file separate from Renode's requirements.

Install them in your virtual environment with `pip install -r requirements.txt`.

### Building from source

For information on building Renode from source, see [the documentation](https://renode.readthedocs.io/en/latest/advanced/building_from_sources.html).

## Running Renode

After following the instructions above on installation from a package, you should have the `renode` command available system-wide:

```
renode [flags] [file]
```

If you built it from source, navigate to the relevant directory and use:

```
./renode [flags] [file]
```

The optional `[file]` argument allows you to provide the path to a script to be run on startup.

The script allows several optional flags, the most useful of which are presented below:

```
-p                  Remove steering codes (e.g., colours) from output
-P      INT32       Instead of opening a window, listen for Monitor commands on the specified port
-e      COMMAND     Execute command on startup (executed after the optional script). May be used multiple times
--console           Run the Monitor in the console instead of a separate window
--disable-gui       Disable XWT GUI support. It automatically sets HideMonitor
--hide-monitor      Do not show the Monitor window
--hide-log          Do not show log messages in console
--hide-analyzers    Do not show analyzers
-v                  Print version and exit
-h                  Display help and usage information
```

Renode can be run on Windows systems with a similar set of optional flags.

### Sample scenario

Below, you can see a piece of firmware running on simulated hardware.
The Renode Monitor is visible alongside an analyzer window displaying UART output and logger.
For more information about this particular setup, see [its dedicated repository](https://github.com/antmicro/renode-tesla-roadster-simulation).

![Renode screencast](./images/renode-screencast.svg "Renode screencast")

### Alternative ways for running Renode on Linux

#### renode-run

`renode-run` is a Python script that downloads and runs Renode, and lets you easily run demos available in [Renodepedia](https://zephyr-dashboard.renode.io/renodepedia/) as well as local ELF files.
Go to [the repository](https://github.com/antmicro/renode-run) for usage instructions.

`renode-run` relies on a portable package and its main advantage is the ease of updating Renode to the latest nightly build using a single command.

#### pyrenode3

`pyrenode3` is a A Python library for interacting with Renode programmatically.
Go to [the repository](https://github.com/antmicro/pyrenode3) for usage instructions.

#### Running Renode in a Docker container

If you want to run Renode in Docker, you can use prebuilt images available on [Docker Hub](https://hub.docker.com/r/antmicro/renode).

To start Renode in interactive mode on Linux, assuming you have Docker installed in your system, run one of the following:

* For the latest numbered version build:
    ```
    docker run -ti -e DISPLAY -v $XAUTHORITY:/home/developer/.Xauthority --net=host antmicro/renode:latest
    ```
* For a nightly mono build:
    ```
    docker run -ti -e DISPLAY -v $XAUTHORITY:/home/developer/.Xauthority --net=host antmicro/renode:nightly
    ```
* For a nightly dotnet build:
    ```
    docker run -ti -e DISPLAY -v $XAUTHORITY:/home/developer/.Xauthority --net=host antmicro/renode:nightly-dotnet
    ```

This will display the Renode Monitor window.
Alternatively, you can provide your custom command at the end of the line above.

To run the image in console mode without X server passthrough, run:

```
docker run -ti antmicro/renode bash
```

You can add more `-v` switches to the command to mount your own directories.

For more information and the underlying Dockerfile, visit the [repository on GitHub](https://github.com/renode/renode-docker).

## Documentation

Documentation is available on [Read the Docs](https://renode.readthedocs.io).

## License & contributions

Renode is released under the permissive MIT license.
For details, see the [LICENSE](LICENSE) file.

We're happy to accept bug reports, feature requests, and contributions via GitHub pull requests / issues.
For details, see the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## Commercial support

Commercial support for Renode is provided by [Antmicro](https://antmicro.com), a company specializing in helping its clients to adopt new embedded technologies and modern development methodologies.

Antmicro created and maintains the Renode Framework and related tooling and is happy to provide services such as adding new platforms, integrations, plugins, and tools.

To inquire about our services, contact us at [support@renode.io](mailto:support@renode.io).
