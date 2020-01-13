Conda packages
==============

This directory contains scripts required to build `Conda <https://conda.io>`_ packages with Renode.

The packages are available at https://anaconda.org/antmicro/renode.

Building packages
-----------------

To build a package you need to have ``conda`` installed on your system.
The easiest way to obtain it is to use the `Miniconda installer <https://docs.conda.io/en/latest/miniconda.html>`_.

You also need to have the ``conda-build`` package installed.
If you have already installed ``conda``, simply run::

    conda install conda-build

Building the package itself is easy.
On Linux and macOS run::

    conda build -c conda-forge path-to-renode/tools/packaging/conda

On Windows, as it does not depend on Mono provided by ``conda-forge``, run::

    conda build path/to/renode/tools/packaging/conda

When the package is built, you can install it with::

    conda install [-c conda-forge] --use-local renode

Using prebuilt packages
-----------------------

To install packages from the ``antmicro`` channel, run::

    conda install [-c conda-forge] -c antmicro renode

The ``conda-forge`` channel is not required on Windows.
