#!/usr/bin/env bash
# Summarise a nanokvm build log.
#
# Usage:
#   ./show-build-errors.sh [logfile]
#
# If no path is given, picks the most recent /tmp/nanokvm-build-*.log.

set -euo pipefail

log="${1:-$(ls -t /tmp/nanokvm-build-*.log 2>/dev/null | head -1)}"

if [ -z "$log" ] || [ ! -f "$log" ]; then
    echo "No build log found. Pass a path or run build-nanokvm.sh first." >&2
    exit 1
fi

echo "==> Log: $log"
echo ""

# ------ Buildroot package-stage markers (>>> package version step) ----------
# Strip ANSI escape codes before matching — buildroot colorises its output.
echo "==> Build stages:"
sed 's/\x1b\[[0-9;]*m//g' "$log" | grep "^>>>" | sed 's/^/  /' || echo "  (none)"
echo ""

# ------ First hard error location -------------------------------------------
# Look for make "*** Error" lines which always mark a real failure.
first_err_line=$(grep -n "make\[.*\]: \*\*\*" "$log" | head -1 | cut -d: -f1)

if [ -z "$first_err_line" ]; then
    echo "==> No make errors found — build may have succeeded."
    exit 0
fi

# Last >>> before the first error = failed package/step
failed_stage=$(sed -n "1,${first_err_line}p" "$log" | sed 's/\x1b\[[0-9;]*m//g' | grep "^>>>" | tail -1)
echo "==> Failed stage: ${failed_stage:-unknown}"
echo ""

# ------ Error lines (compiler errors, script ERRORs, make failures) ---------
echo "==> Error lines:"
grep -n -E "(^[^:]+:[0-9]+: error:|: error:|^ERROR:|make\[.*\]: \*\*\*)" "$log" \
    | grep -v "^Binary file" \
    | head -60 \
    | sed 's/^/  /'
echo ""

# ------ Context around first make failure ------------------------------------
echo "==> Context around first failure (line ${first_err_line}):"
start=$(( first_err_line > 10 ? first_err_line - 10 : 1 ))
sed -n "${start},$((first_err_line + 5))p" "$log" | sed 's/^/  /'
