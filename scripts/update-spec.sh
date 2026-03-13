#!/usr/bin/env bash
set -euo pipefail

COMMIT="${1:?Usage: $0 <commit-sha>}"
SPEC_FILE="${SPEC_FILE:-SPECS/qemu-kvm.spec}"
AUTHOR_NAME="${AUTHOR_NAME:-CI Bot}"
AUTHOR_EMAIL="${AUTHOR_EMAIL:-ci@nvidia.com}"
COMMIT_LOG_FILE="${COMMIT_LOG_FILE:-.upstream-commits}"

# ── 1. Pin the commit SHA in the spec ──────────────────────────────────────
echo "==> Setting %%global commit to ${COMMIT}"
sed -i "s/^%global commit .*/%global commit ${COMMIT}/" "$SPEC_FILE"

# ── 2. Bump Release number ─────────────────────────────────────────────────
CURRENT_RELEASE=$(grep -m1 '^Release:' "$SPEC_FILE" \
  | sed 's/Release:[[:space:]]*//' \
  | grep -oP '^\d+')
NEW_RELEASE=$((CURRENT_RELEASE + 1))

echo "==> Bumping Release: ${CURRENT_RELEASE} -> ${NEW_RELEASE}"
sed -i "0,/^Release:[[:space:]]*${CURRENT_RELEASE}/s/^Release:[[:space:]]*${CURRENT_RELEASE}/Release: ${NEW_RELEASE}/" "$SPEC_FILE"
