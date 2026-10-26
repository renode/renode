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

THIS_DIR="$(cd $(dirname $0); echo $PWD)"
BASE_PATH=$THIS_DIR/../../src/Infrastructure/src/

# Ignored since these templates are not to be generated and used directly
IGNORED_FILENAMES=("RegisterTemplateDefinitions.tt" "RegisterTemplate.tt" "RegisterEnumParserContent.tt")

mapfile -d '' -t FILES < <(find "$BASE_PATH" -type f -name '*.tt' -print0)

for file in "${FILES[@]}"; do

    filename="$(basename "$file")"
    for ignored_filename in "${IGNORED_FILENAMES[@]}"; do
        [[ "$filename" == "$ignored_filename" ]] && continue 2
    done

    echo "Parsing $file"
    t4 -p:BASE_PATH="$BASE_PATH" -o "${file%.tt}.cs" "$file"

    # Remove trailing invisible newline
    truncate -s -1 ${file%.tt}.cs
done
