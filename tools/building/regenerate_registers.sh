#!/usr/bin/env bash
set -x
set -e

THIS_DIR="$(cd $(dirname $0); echo $PWD)"

CORES_PATH=$THIS_DIR/../../src/Infrastructure/src/Emulator/Cores
BASE_PATH=$THIS_DIR/../../src/Infrastructure/src/Emulator/Cores/Common/

FILES=(Sparc/Sparc Arm/Arm Arm64/ARMv8A Arm64/ARMv8R Arm-M/CortexM PowerPC/PowerPc PowerPC/PowerPc64 RiscV/RiscV32 RiscV/RiscV64 X86/X86 Xtensa/Xtensa X86/X86_64 X86KVM/X86KVM/X86KVM X86KVM/X86_64KVM/X86_64KVM)

for file in ${FILES[@]}; do
    # dotnet-t4 tool used to process T4 templates must be installed separately:
    # dotnet tool install -g dotnet-t4
    # https://github.com/mono/t4/pkgs/nuget/dotnet-t4
    t4 -p:BASE_PATH=$BASE_PATH -o $CORES_PATH/${file}Registers.{cs,tt}
    # Remove trailing invisible newline
    truncate -s -1 $CORES_PATH/${file}Registers.cs
done
