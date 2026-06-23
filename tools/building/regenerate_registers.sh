#!/usr/bin/env bash

set -eu

# dotnet-t4 tool used to process T4 templates must be installed separately
# https://github.com/mono/t4/pkgs/nuget/dotnet-t4
if ! (t4 -h &>/dev/null); then
    exec >&2
    echo "dotnet-t4 tool necessary to regenerate source files is missing."
    echo
    echo "It can be installed with:"
    echo "  dotnet tool install -g dotnet-t4"
    exit 1
fi

set -x

THIS_DIR="$(cd $(dirname $0); echo $PWD)"

CORES_PATH=$THIS_DIR/../../src/Infrastructure/src/Emulator/Cores
BASE_PATH=$THIS_DIR/../../src/Infrastructure/src/Emulator/Cores/Common/

FILES=(Sparc/Sparc Arm/Arm Arm64/ARMv8A Arm64/ARMv8R Arm-M/CortexM PowerPC/PowerPc PowerPC/PowerPc64 RiscV/RiscV32 RiscV/RiscV64 X86/X86 Xtensa/Xtensa X86/X86_64 KVM/X86/X86KVM KVM/X86/X86_64KVM)

for file in ${FILES[@]}; do
    t4 -p:BASE_PATH=$BASE_PATH -o $CORES_PATH/${file}Registers.{cs,tt}
    # Remove trailing invisible newline
    truncate -s -1 $CORES_PATH/${file}Registers.cs
done
