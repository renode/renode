#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "usage: $0 implib placeholder replacement" >&2
    exit 1
fi

implib=$1
placeholder=$2
replacement=$3

if [[ "${#placeholder}" -ne "${#replacement}" ]]; then
    echo "placeholder and replacement lengths differ" >&2
    exit 1
fi

implib_dir=$(dirname "$implib")
offsets="${implib_dir}/patch-import-library.tmp"
trap 'rm -f "$offsets"' EXIT HUP INT TERM

if ! grep -Fabo -- "$placeholder" "$implib" > "$offsets"; then
    echo "placeholder not found in $implib" >&2
    exit 1
fi

while IFS=: read -r offset _; do
    printf '%s' "$replacement" | dd of="$implib" oflag=seek_bytes seek="$offset" conv=notrunc 2>/dev/null
done < "$offsets"
