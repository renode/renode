#!/usr/bin/env bash

prepare_portable_native_interface_runtime() {
    local PUBLISH_DIR="$1"
    local OUTPUT_BIN_DIR="$2"

    local DOTNET_RUNTIME_CONFIG="$PUBLISH_DIR/Renode.runtimeconfig.json"
    local DOTNET_RUNTIME_VERSION
    DOTNET_RUNTIME_VERSION="$(sed -nE 's/.*"version":[[:space:]]*"([^"]+)".*/\1/p' "$DOTNET_RUNTIME_CONFIG" | head -n1)"

    local HOSTFXR_NAME="libhostfxr.so"
    if $ON_OSX; then
        HOSTFXR_NAME="libhostfxr.dylib"
    elif $ON_WINDOWS; then
        HOSTFXR_NAME="hostfxr.dll"
    fi

    # librenode is initialised through hostfxr's command-line startup path, so
    # portable packages can use the same flat self-contained runtime layout as
    # the Renode executable. Only hostfxr needs its standard discovery location.
    # See the runtimeconfig path in DNNE:
    # https://github.com/AaronRobinsonMSFT/DNNE/blob/45f1f180c2f5ef9314dfdeebf4192ce081a54fcf/src/platform/platform.c#L468
    # DNNE's nethost RID setup:
    # https://github.com/AaronRobinsonMSFT/DNNE/blob/45f1f180c2f5ef9314dfdeebf4192ce081a54fcf/src/msbuild/DNNE.targets#L66
    local DESTINATION_HOSTFXR_DIR="$OUTPUT_BIN_DIR/host/fxr/$DOTNET_RUNTIME_VERSION"
    mkdir -p "$DESTINATION_HOSTFXR_DIR"
    cp "$PUBLISH_DIR/$HOSTFXR_NAME" "$DESTINATION_HOSTFXR_DIR"
}
