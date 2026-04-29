#!/bin/bash -e
#
# Build a minimal NanoKVM image.
#
# Usage:
#   ./build-nanokvm.sh [--clean] [--no-shrink] [--from-source]
#
# Options:
#   --clean         Wipe all build artifacts for the nanokvm board before
#                   building. Keeps the buildroot download cache (buildroot/dl/)
#                   so packages do not need to be re-downloaded.
#   --no-shrink     Keep all default buildroot packages (larger image, useful
#                   for debugging; still adds nanokvm and ser2net)
#   --from-source   Build NanoKVM from source (Go + React + CGO) using the
#                   nanokvm-server + nanokvm-sg200x packages instead of the
#                   pre-built binary release. Much slower but allows patching.
#
# How it works:
#   1. Sources the build environment and selects the sg2002_nanokvm_sd board.
#   2. Derives a NanoKVM buildroot config by applying a package delta on top
#      of the base cvitek_SG200X_musl_riscv64_defconfig (sed-based merge).
#      The base defconfig is never modified; the derived one is ephemeral.
#   3. Overrides BR_DEFCONFIG and calls build_all.
#   4. Removes the ephemeral config after build.
#
# See NANOKVM.md for the full build guide.

clean=n
shrink=y
prebuilt=y

while [ "$#" -gt 0 ]; do
    case "$1" in
        --clean)
            clean=y
            shift
            ;;
        --no-shrink)
            shrink=n
            shift
            ;;
        --from-source)
            prebuilt=n
            shift
            ;;
        --help|-h)
            sed -n '3,/^[^#]/{ /^#/{ s/^# \?//; p }; /^[^#]/q }' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--clean] [--no-shrink] [--from-source]" >&2
            exit 1
            ;;
    esac
done

BOARD="sg2002_nanokvm_sd"
INSTALL_DIR="install/soc_${BOARD}"
PARTITION_XML="build/boards/sg200x/${BOARD}/partition/partition_sd.xml"

# ---- Log tee ----------------------------------------------------------------
BUILD_LOG="/tmp/nanokvm-build-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee "$BUILD_LOG") 2>&1
echo "==> Build log: $BUILD_LOG"

# ---- Docker / volume-mount safety ----------------------------------------
# When building inside Docker with the repo mounted from the host:
# 1. Git refuses to operate because the mount is owned by the host user but
#    the container runs as root.
# 2. Stale .d dependency files from a previous host build embed the host's
#    absolute path, breaking the build immediately.
# Both are safe to fix unconditionally.

git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

# Always wipe .d files — they embed absolute srctree paths and break the
# build when switching between host and Docker environments.
find middleware u-boot-2021.10/build -name "*.d" -delete 2>/dev/null || true
find middleware -name "*.o" -delete 2>/dev/null || true

# Ensure the middleware lib output directory exists. The sensor component
# build races with the module build under -j$(nproc); if lib/ is absent
# (fresh checkout or after --clean), the ar/ld step fails immediately.
mkdir -p middleware/v2/lib/3rd

# ---- Clean (optional) ----------------------------------------------------
if [ "${clean}" = "y" ]; then
    echo "==> Cleaning build artifacts for ${BOARD}..."

    # Per-board build directories
    rm -rf "build/output/${BOARD}"
    rm -rf "linux_5.10/build/${BOARD}"
    rm -rf "u-boot-2021.10/build/${BOARD}"
    rm -rf "${INSTALL_DIR}"

    # Middleware compiled objects and libraries.
    # Keep middleware/v2/lib/ as a directory — the sensor component build
    # races with the module build under -j$(nproc) and will fail if the
    # directory does not already exist when it tries to create archives.
    find middleware/v2 -name "*.o" -delete 2>/dev/null || true
    find middleware/v2/lib -name "*.a" -delete 2>/dev/null || true
    find middleware/v2/lib -name "*.so" -delete 2>/dev/null || true
    rm -rf middleware/v2/mod_tmp 2>/dev/null || true

    # FSBL and OpenSBI in-tree build artifacts
    rm -rf fsbl/build 2>/dev/null || true
    find opensbi -name "*.o" -delete 2>/dev/null || true

    # Buildroot output — all built packages for the SG200X config.
    # Keeps buildroot/dl/ (download cache) to avoid re-fetching sources.
    rm -rf buildroot/output 2>/dev/null || true

    echo "==> Clean complete."
    echo ""
fi

# ---- Build environment ---------------------------------------------------
source build/cvisetup.sh
defconfig "${BOARD}"

# ---- Derive NanoKVM buildroot config ------------------------------------
# The base cvitek_SG200X_musl_riscv64_defconfig is never modified.
# We generate an ephemeral nanokvm variant from it on each run.
NANOKVM_DEFCONFIG_NAME="cvitek_SG200X_nanokvm_defconfig"
NANOKVM_DEFCONFIG="buildroot/configs/${NANOKVM_DEFCONFIG_NAME}"

# Apply the NanoKVM config fragment (shrink mode) or copy the base defconfig
# as-is (--no-shrink).  The fragment is the version-controlled source of truth
# for the package delta; see buildroot/configs/nanokvm.fragment.
if [ "${shrink}" = "y" ]; then
    # CONFIG_= tells merge_config.sh to use an empty symbol prefix (Buildroot
    # uses BR2_ directly, unlike the Linux kernel which uses CONFIG_).
    CONFIG_= KCONFIG_CONFIG="${NANOKVM_DEFCONFIG}" \
        buildroot/support/kconfig/merge_config.sh -m \
        "buildroot/configs/${BR_DEFCONFIG}" \
        "buildroot/configs/nanokvm.fragment"
else
    cp "buildroot/configs/${BR_DEFCONFIG}" "${NANOKVM_DEFCONFIG}"
    # Fragment adds ser2net; in --no-shrink mode enable it manually instead.
    sed -i 's/^# BR2_PACKAGE_SER2NET is not set/BR2_PACKAGE_SER2NET=y/' "${NANOKVM_DEFCONFIG}"
fi

# Append the mode-specific NanoKVM application package.
if [ "${prebuilt}" = "y" ]; then
    echo "==> Using pre-built NanoKVM binary (use --from-source to build from source)"
    printf '\nBR2_PACKAGE_NANOKVM_PREBUILT=y\n' >> "${NANOKVM_DEFCONFIG}"
    NANOKVM_PKG="BR2_PACKAGE_NANOKVM_PREBUILT"
else
    echo "==> Building NanoKVM from source (Go + React + CGO)"
    printf '\nBR2_PACKAGE_NANOKVM_SG200X=y\n' >> "${NANOKVM_DEFCONFIG}"
    NANOKVM_PKG="BR2_PACKAGE_NANOKVM_SG200X"
fi

if ! grep -q "${NANOKVM_PKG}=y" "${NANOKVM_DEFCONFIG}"; then
    echo "ERROR: NanoKVM package not found in derived config — merge may have failed." >&2
    rm -f "${NANOKVM_DEFCONFIG}"
    exit 1
fi

# ---- Rootfs / partition size (single source of truth) ----------------------
# Change ROOTFS_SIZE_MB here; the partition XML is rewritten automatically.
# Also update BR2_TARGET_ROOTFS_EXT2_SIZE in nanokvm.fragment if you change this.
ROOTFS_SIZE_MB=1000

# ext4 images have ~6 KB of alignment overhead; add a full MiB of clearance.
ROOTFS_PARTITION_KB=$(( ROOTFS_SIZE_MB * 1024 + 1024 ))

sed -i "s/^BR2_TARGET_ROOTFS_EXT2_SIZE=.*/BR2_TARGET_ROOTFS_EXT2_SIZE=\"${ROOTFS_SIZE_MB}M\"/" \
    "${NANOKVM_DEFCONFIG}"

sed -i "s/\(label=\"ROOTFS\"[^/]*size_in_kb=\"\)[0-9]*/\1${ROOTFS_PARTITION_KB}/" \
    "${PARTITION_XML}"
echo "==> Rootfs: ${ROOTFS_SIZE_MB} MiB image → ${ROOTFS_PARTITION_KB} KB partition slot"

# ---- Build ---------------------------------------------------------------
export BR_DEFCONFIG="${NANOKVM_DEFCONFIG_NAME}"

build_all
BUILD_STATUS=$?

# Clean up ephemeral config — always regenerated from the base
rm -f "${NANOKVM_DEFCONFIG}"

# build_all does not reliably propagate sub-make failures; verify key outputs.
if [ "${BUILD_STATUS}" -ne 0 ]; then
    echo "" >&2
    echo "ERROR: build_all reported failure (exit ${BUILD_STATUS})." >&2
    exit "${BUILD_STATUS}"
fi
if [ ! -f "${INSTALL_DIR}/fip.bin" ]; then
    echo "" >&2
    echo "ERROR: build completed but fip.bin is missing — a sub-build likely failed." >&2
    echo "  Tip: run with --clean to eliminate stale artifacts, then retry." >&2
    exit 1
fi

IMAGE=$(ls -t "${INSTALL_DIR}/images/"*.img 2>/dev/null | head -1)

echo ""
echo "Build complete. Image: ${INSTALL_DIR}/"
if [ -n "${IMAGE}" ]; then
    echo ""
    echo "Flash to SD card:"
    echo "  sudo dd if=${IMAGE} of=/dev/sdX bs=4M conv=fsync status=progress"
    echo ""
    echo "File name: $(basename ${IMAGE})"
fi

