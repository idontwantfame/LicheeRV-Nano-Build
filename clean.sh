#!/usr/bin/env bash
# Remove build artifacts. By default keeps buildroot/dl (1+ GB, slow to re-download).
# Pass --dl to also wipe the download cache.

set -euo pipefail

CLEAN_DL=0
for arg in "$@"; do
    case "$arg" in
        --dl) CLEAN_DL=1 ;;
        -h|--help)
            echo "Usage: $0 [--dl]"
            echo "  --dl   Also remove buildroot/dl/ (downloaded source tarballs)"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

rm_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "Removing $dir ($(du -sh "$dir" 2>/dev/null | cut -f1))..."
        rm -rf "$dir"
    fi
}

# Main buildroot output (host tools, per-package dirs, target, images)
rm_dir buildroot/output

# Final SD card images
rm_dir install

# Component build trees
rm_dir linux_5.10/build
rm_dir fsbl/build
rm_dir u-boot-2021.10/build
rm_dir freertos/build

# pnpm cache dropped into repo root
rm_dir .pnpm-store

if [ "$CLEAN_DL" -eq 1 ]; then
    rm_dir buildroot/dl
else
    echo "Keeping buildroot/dl (pass --dl to also remove)"
fi

echo "Done."
