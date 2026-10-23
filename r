#!/bin/bash
#
# This is just an entry script that passes all the work to scripts/silabs-dev/main.js

if [ "$#" -eq 1 ] && [ "$1" = "init" ]; then
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$_script_dir/scripts/silabs-dev" && npm ci
else
  env node scripts/silabs-dev/main.js "$@"
fi
