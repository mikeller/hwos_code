#!/usr/bin/env bash
# Install a verified, explicitly UNVALIDATED OSTC3 package using Subsurface.
# This is deliberately invoked only by `make install`, never by `make`.
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

metadata_value() {
	local key=$1
	local info_file=$2
	awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit }' "$info_file"
}

DEVICE=${DEVICE:-}
CONFIRM_UNVALIDATED_OSTC3=${CONFIRM_UNVALIDATED_OSTC3:-}
FIRMWARE_INSTALLER=${FIRMWARE_INSTALLER:-subsurface-downloader}
DC_VENDOR=${DC_VENDOR:-'Heinrichs Weikamp'}
DC_PRODUCT=${DC_PRODUCT:-'OSTC 3'}

[[ -n "$DEVICE" ]] || fail 'DEVICE is required; specify the exact device, for example: make install DEVICE=AA:BB:CC:DD:EE:FF CONFIRM_UNVALIDATED_OSTC3=YES'
[[ "$DEVICE" != *$'\n'* && "$DEVICE" != *$'\r'* ]] || fail 'DEVICE must not contain a newline'
[[ "$DEVICE" != auto && "$DEVICE" != AUTO ]] || fail 'automatic device selection is not permitted; provide the exact DEVICE'
[[ "$CONFIRM_UNVALIDATED_OSTC3" == YES ]] || fail 'set CONFIRM_UNVALIDATED_OSTC3=YES to acknowledge that this package is unvalidated firmware'
[[ -n "$DC_VENDOR" && -n "$DC_PRODUCT" ]] || fail 'DC_VENDOR and DC_PRODUCT must be non-empty'

INSTALLER_PATH=$(command -v "$FIRMWARE_INSTALLER") || fail "subsurface-downloader was not found: $FIRMWARE_INSTALLER"

cd "$ROOT_DIR"
[[ -z "$(git status --porcelain)" ]] || fail 'refusing to install from a worktree with uncommitted changes'
BRANCH=$(git symbolic-ref --quiet --short HEAD) || fail 'refusing to install from a detached HEAD'
COMMIT=$(git rev-parse HEAD)
SAFE_BRANCH=$(printf '%s' "$BRANCH" | sed 's/[^A-Za-z0-9._-]\+/-/g')
[[ -n "$SAFE_BRANCH" ]] || fail "cannot derive a safe package name from branch: $BRANCH"
PACKAGE_NAME="hwos_ostc3_${SAFE_BRANCH}_${COMMIT:0:12}_UNVALIDATED_firmware.hex"
FINAL_ARTIFACT_DIR=${ARTIFACT_DIR:-"$ROOT_DIR/build/windows/$COMMIT"}
if [[ "$FINAL_ARTIFACT_DIR" != /* ]]; then
	FINAL_ARTIFACT_DIR="$ROOT_DIR/$FINAL_ARTIFACT_DIR"
fi

# This verifies that the exact current pushed commit is built, or reuses its
# already verified package. It never flashes or uploads.
"$ROOT_DIR/tools/build_hwos.sh"

BUILD_INFO="$FINAL_ARTIFACT_DIR/build-info.txt"
PACKAGE="$FINAL_ARTIFACT_DIR/$PACKAGE_NAME"
[[ -f "$BUILD_INFO" ]] || fail "build metadata is missing: $BUILD_INFO"
[[ "$(metadata_value source_commit "$BUILD_INFO")" == "$COMMIT" ]] || fail 'build metadata does not identify the current commit'
[[ "$(metadata_value source_branch "$BUILD_INFO")" == "$BRANCH" ]] || fail 'build metadata does not identify the current branch'
[[ "$(metadata_value ostc3_package "$BUILD_INFO")" == *UNVALIDATED* ]] || fail 'build metadata does not identify an UNVALIDATED OSTC3 package'
[[ -s "$PACKAGE" ]] || fail "expected package is missing or empty: $PACKAGE"
EXPECTED_HASH=$(metadata_value ostc3_package_sha256 "$BUILD_INFO")
[[ -n "$EXPECTED_HASH" ]] || fail 'build metadata has no OSTC3 package hash'
ACTUAL_HASH=$(sha256sum "$PACKAGE" | awk '{print $1}')
[[ "$ACTUAL_HASH" == "$EXPECTED_HASH" ]] || fail "package SHA-256 mismatch: expected $EXPECTED_HASH, got $ACTUAL_HASH"

printf 'Installing UNVALIDATED OSTC3 package for %s/%s on explicit device %s\n' "$DC_VENDOR" "$DC_PRODUCT" "$DEVICE"
exec "$INSTALLER_PATH" \
	--update-firmware \
	--dc-vendor="$DC_VENDOR" \
	--dc-product="$DC_PRODUCT" \
	--device="$DEVICE" \
	--firmware-file="$PACKAGE"
