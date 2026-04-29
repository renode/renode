#!/usr/bin/env bash

copy_native_interface_runtime_config() {
    local build_dir="$1"
    local platform_lib_dir="$2"

    if [ ! -f "$platform_lib_dir/RenodeNativeInterface.dll" ]; then
        return
    fi

    cp "$build_dir/Renode.runtimeconfig.json" "$platform_lib_dir/RenodeNativeInterface.runtimeconfig.json"
}

copy_native_interface_runtime_configs() {
    local build_dir="$1"
    local platform_lib_dir="$2"

    if [ ! -d "$platform_lib_dir" ]; then
        return
    fi

    find "$platform_lib_dir" -mindepth 2 -maxdepth 2 -type f -name RenodeNativeInterface.dll | while read -r native_interface; do
        copy_native_interface_runtime_config "$build_dir" "$(dirname "$native_interface")"
    done
}
