#!/usr/bin/env bash
# Build the hwOS PIC18 firmware with Microchip MPLAB C18.
# The resulting hwos_tiny.hex is suitable for the existing TinyBld workflow.
set -euo pipefail

readonly ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly BUILD_DIR=${BUILD_DIR:-"$ROOT_DIR/build"}
readonly OBJECT_DIR="$BUILD_DIR/obj"
readonly PROCESSOR=18F87K22

# Set C18_BIN when the legacy C18 tools are not on PATH, for example:
# C18_BIN=/opt/microchip/mplabc18/v3.47/bin make build
readonly C18_BIN=${C18_BIN:-}
MCC18=${MCC18:-"${C18_BIN:+$C18_BIN/}mcc18"}
MPASM=${MPASM:-"${C18_BIN:+$C18_BIN/}mpasmx"}
MPLINK=${MPLINK:-"${C18_BIN:+$C18_BIN/}mplink"}
SREC_CAT=${SREC_CAT:-srec_cat}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: required tool not found: %s\n' "$1" >&2
        printf '       install MPLAB C18 v3.42 or newer and srecord, or set C18_BIN/MCC18/MPASM/MPLINK/SREC_CAT.\n' >&2
        exit 127
    fi
}

require_tool "$MCC18"
require_tool "$MPASM"
require_tool "$MPLINK"
require_tool "$SREC_CAT"

rm -rf "$OBJECT_DIR"
mkdir -p "$OBJECT_DIR"

objects=()
for source in "$ROOT_DIR"/src/*.asm; do
    object="$OBJECT_DIR/$(basename "${source%.asm}").o"
    printf 'ASM  %s\n' "${source#"$ROOT_DIR/"}"
    "$MPASM" /q "/p$PROCESSOR" "/o$object" "$source"
    objects+=("$object")
done

for source in "$ROOT_DIR"/src/*.c; do
    object="$OBJECT_DIR/$(basename "${source%.c}").o"
    printf 'C18  %s\n' "${source#"$ROOT_DIR/"}"
    "$MCC18" "-p=$PROCESSOR" "-I$ROOT_DIR/src" "-fo=$object" "$source"
    objects+=("$object")
done

readonly FULL_HEX="$BUILD_DIR/hwos.production.hex"
readonly TINY_HEX="$BUILD_DIR/hwos_tiny.hex"
printf 'LINK %s\n' "${FULL_HEX#"$ROOT_DIR/"}"
"$MPLINK" "/p$PROCESSOR" /w "/m$BUILD_DIR/hwos.map" "/o$FULL_HEX" \
    "/l$ROOT_DIR/src/18F87K22_hwos.lkr" "${objects[@]}"

# TinyBld must not receive the logo/program area beginning at 0x1E000.
printf 'CROP %s\n' "${TINY_HEX#"$ROOT_DIR/"}"
"$SREC_CAT" "$FULL_HEX" -Intel -crop 0x00000 0x1E000 -o "$TINY_HEX" -Intel

if [[ ! -s "$TINY_HEX" ]] || ! grep -q '^:00000001FF' "$TINY_HEX"; then
    printf 'error: generated upload HEX is empty or has no Intel HEX EOF record: %s\n' "$TINY_HEX" >&2
    exit 1
fi

{
    printf 'source_commit=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
    printf 'processor=%s\n' "$PROCESSOR"
    printf 'full_hex_sha256=%s\n' "$(sha256sum "$FULL_HEX" | awk '{print $1}')"
    printf 'upload_hex_sha256=%s\n' "$(sha256sum "$TINY_HEX" | awk '{print $1}')"
} > "$BUILD_DIR/build-info.txt"

printf '\nUpload artefact: %s\n' "$TINY_HEX"
printf 'Build metadata:  %s\n' "$BUILD_DIR/build-info.txt"
