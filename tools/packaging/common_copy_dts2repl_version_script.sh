#!/usr/bin/env bash

BASE=$1
DESTINATION=$2

DTS2REPL_SCRIPT=$DESTINATION/tools/dts2repl-version.sh

# Search for marker in the original script and add 1 to skip also the line with marker
SKIP_LINES=$(grep "END OF VERSION CHECK" $BASE/tools/dts2repl-version.sh -n | cut -f1 -d:)
SKIP_LINES=$((SKIP_LINES + 1))

# Get current dts2repl version
DTS2REPL_VERSION=$($BASE/tools/dts2repl-version.sh --commit)

# Construct dts2repl-version.sh script
install -m 755 /dev/null $DTS2REPL_SCRIPT
cat <<EOF >>$DTS2REPL_SCRIPT
#!/usr/bin/env bash
DTS2REPL_VERSION=$DTS2REPL_VERSION
EOF

tail -n +$SKIP_LINES $BASE/tools/dts2repl-version.sh >> $DTS2REPL_SCRIPT
