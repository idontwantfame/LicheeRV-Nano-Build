#!/bin/bash -e
#
# Bump nanokvm-prebuilt to a new release.
#
# Usage:
#   ./update-nanokvm-prebuilt.sh [VERSION]
#
# If VERSION is omitted the latest GitHub release is used.
# Strips a leading 'v' from VERSION if present (tags vary in the project).
#
# What it does:
#   1. Resolves the target version (argument or GitHub API).
#   2. Downloads sha256.txt from that release and extracts the tarball hash.
#   3. Updates NANOKVM_PREBUILT_VERSION in nanokvm-prebuilt.mk.
#   4. Rewrites nanokvm-prebuilt.hash with the new hash.

REPO="sipeed/NanoKVM"
MK="buildroot/package/nanokvm-prebuilt/nanokvm-prebuilt.mk"
HASH_FILE="buildroot/package/nanokvm-prebuilt/nanokvm-prebuilt.hash"

# ---- Resolve version --------------------------------------------------------
if [ -n "$1" ]; then
    VERSION="${1#v}"          # strip leading 'v' if present
else
    echo "==> Fetching latest release from GitHub..."
    TAG=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    if [ -z "${TAG}" ]; then
        echo "ERROR: could not determine latest release (rate-limited or no network?)" >&2
        exit 1
    fi
    VERSION="${TAG#v}"
    echo "==> Latest: ${VERSION}"
fi

CURRENT=$(grep 'NANOKVM_PREBUILT_VERSION' "${MK}" | sed 's/.*= *//')
if [ "${VERSION}" = "${CURRENT}" ]; then
    echo "Already at ${VERSION} — nothing to do."
    exit 0
fi

# ---- Fetch sha256.txt -------------------------------------------------------
TARBALL="nanokvm_${VERSION}.tar.gz"
SHA256_URL="https://github.com/${REPO}/releases/download/${VERSION}/sha256.txt"

echo "==> Fetching ${SHA256_URL}..."
SHA256_TXT=$(curl -sf "${SHA256_URL}") || {
    echo "ERROR: could not fetch ${SHA256_URL}" >&2
    echo "  Check that release ${VERSION} exists and has a sha256.txt asset." >&2
    exit 1
}

# sha256.txt lines are either "HASH  filename" or "HASH *filename"
HASH_VALUE=$(echo "${SHA256_TXT}" | grep "${TARBALL}" | awk '{print $1}')
if [ -z "${HASH_VALUE}" ]; then
    echo "ERROR: ${TARBALL} not found in sha256.txt" >&2
    echo "sha256.txt contents:" >&2
    echo "${SHA256_TXT}" >&2
    exit 1
fi

echo "==> SHA256: ${HASH_VALUE}"

# ---- Update files -----------------------------------------------------------
sed -i "s/^NANOKVM_PREBUILT_VERSION = .*/NANOKVM_PREBUILT_VERSION = ${VERSION}/" "${MK}"

cat > "${HASH_FILE}" <<EOF
# From https://github.com/${REPO}/releases/download/${VERSION}/sha256.txt
sha256  ${HASH_VALUE}  ${TARBALL}
EOF

echo ""
echo "Updated ${CURRENT} → ${VERSION}"
echo "  ${MK}"
echo "  ${HASH_FILE}"
echo ""
echo "Review the iptables/NTP patches in nanokvm-prebuilt.mk against the new release"
echo "before building — upstream init scripts may have changed."
