#!/usr/bin/env bash
set -euo pipefail

COMMIT="${1:?Usage: $0 <commit-sha>}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/NVIDIA/QEMU.git}"
SPEC_FILE="${SPEC_FILE:-SPECS/qemu-kvm.spec}"
SOURCES_DIR="${SOURCES_DIR:-SOURCES}"
COMMIT_LOG_FILE="${COMMIT_LOG_FILE:-.upstream-commits}"

VERSION=$(grep -m1 '^Version:' "$SPEC_FILE" | awk '{print $2}')
EXTRACT_DIR="qemu-${VERSION}"
TARBALL_NAME="qemu-${VERSION}.tar.xz"

OLD_COMMIT=$(grep -m1 '^%global commit' "$SPEC_FILE" | awk '{print $3}')

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Cloning NVIDIA/QEMU..."
git clone --filter=blob:none "$UPSTREAM_REPO" "$WORKDIR/src"

pushd "$WORKDIR/src" > /dev/null
echo "==> Checking out ${COMMIT}..."
git checkout "$COMMIT"

# ── Extract commit log for changelog ────────────────────────────────────
echo "==> Generating upstream commit log..."
if [ "$OLD_COMMIT" != "unknown" ] && git rev-parse --verify "$OLD_COMMIT" >/dev/null 2>&1; then
    echo "    range: ${OLD_COMMIT:0:12}..${COMMIT:0:12}"
    git log --oneline --no-merges "${OLD_COMMIT}..HEAD" | head -100 > "$OLDPWD/$COMMIT_LOG_FILE"
else
    echo "    no previous commit — using HEAD only"
    git log --oneline --no-merges -1 > "$OLDPWD/$COMMIT_LOG_FILE"
fi
echo "    $(wc -l < "$OLDPWD/$COMMIT_LOG_FILE") commit(s) recorded"

echo "==> Initializing submodules..."
git submodule update --init --recursive --depth=1

echo "==> Downloading meson subprojects..."
meson subprojects download || true
popd > /dev/null

echo "==> Preparing source tree as ${EXTRACT_DIR}/..."
mv "$WORKDIR/src" "$WORKDIR/${EXTRACT_DIR}"

find "$WORKDIR/${EXTRACT_DIR}" -name '.git' -exec rm -rf {} + 2>/dev/null || true

echo "==> Creating ${TARBALL_NAME}..."
tar -C "$WORKDIR" -cf - "${EXTRACT_DIR}" | xz -T0 -3 > "${SOURCES_DIR}/${TARBALL_NAME}"

echo "==> Done: ${SOURCES_DIR}/${TARBALL_NAME}"
ls -lh "${SOURCES_DIR}/${TARBALL_NAME}"
