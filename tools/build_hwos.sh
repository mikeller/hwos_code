#!/usr/bin/env bash
# Build the hwOS PIC18 firmware with Microchip MPLAB C18.
# The resulting hwos_tiny.hex is suitable for the existing TinyBld workflow.
set -euo pipefail

readonly ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-"$ROOT_DIR/build"}
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$ROOT_DIR/$BUILD_DIR"
fi
readonly BUILD_DIR
readonly OBJECT_DIR="$BUILD_DIR/obj"
readonly PROCESSOR=18F87K22

# Set C18_BIN when the legacy C18 tools are not on PATH, for example:
# C18_BIN=/opt/microchip/mplabc18/v3.42/bin make build
readonly C18_BIN=${C18_BIN:-}
MCC18=${MCC18:-"${C18_BIN:+$C18_BIN/}mcc18"}
if [[ -n "$C18_BIN" ]]; then
    MPASM=${MPASM:-"$(dirname -- "$C18_BIN")/mpasm/mpasmx"}
else
    MPASM=${MPASM:-mpasmx}
fi
MPLINK=${MPLINK:-"${C18_BIN:+$C18_BIN/}mplink"}
SREC_CAT=${SREC_CAT:-srec_cat}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: required tool not found: %s\n' "$1" >&2
        printf '       install the vendor-matched MPLAB C18 v3.42 toolchain and srecord, or set C18_BIN/MCC18/MPASM/MPLINK/SREC_CAT.\n' >&2
        exit 127
    fi
}

require_tool "$MCC18"
require_tool "$MPASM"
require_tool "$MPLINK"
require_tool "$SREC_CAT"

MCC18_PATH=$(command -v "$MCC18")
C18_LIBRARY_DIR=$(cd -- "$(dirname -- "$MCC18_PATH")/../lib" && pwd)
if [[ ! -f "$C18_LIBRARY_DIR/clib.lib" || ! -f "$C18_LIBRARY_DIR/p18F87K22.lib" ]]; then
    printf 'error: MPLAB C18 libraries were not found beside %s\n' "$MCC18_PATH" >&2
    printf '       expected clib.lib and p18F87K22.lib in %s\n' "$C18_LIBRARY_DIR" >&2
    exit 127
fi

rm -rf "$OBJECT_DIR"
mkdir -p "$OBJECT_DIR"

objects=()
for source in "$ROOT_DIR"/src/*.asm; do
    object="$OBJECT_DIR/$(basename "${source%.asm}").o"
    printf 'ASM  %s\n' "${source#"$ROOT_DIR/"}"
    (
        cd "$ROOT_DIR/src"
        "$MPASM" /q "/p$PROCESSOR" "/o$object" "/e$OBJECT_DIR/$(basename "${source%.asm}").err" "/l$OBJECT_DIR/$(basename "${source%.asm}").lst" "$(basename "$source")"
    )
    objects+=("$object")
done

for source in "$ROOT_DIR"/src/*.c; do
    object="$OBJECT_DIR/$(basename "${source%.c}").o"
    printf 'C18  %s\n' "${source#"$ROOT_DIR/"}"
    "$MCC18" "-p=$PROCESSOR" "-I=$ROOT_DIR/src" "-fo=$object" "-fe=$OBJECT_DIR/$(basename "${source%.c}").err" "$source"
    objects+=("$object")
done

readonly FULL_HEX="$BUILD_DIR/hwos.production.hex"
readonly TINY_HEX="$BUILD_DIR/hwos_tiny.hex"
printf 'LINK %s\n' "${FULL_HEX#"$ROOT_DIR/"}"
(
    cd "$C18_LIBRARY_DIR"
    "$MPLINK" "/p$PROCESSOR" /w "/m$BUILD_DIR/hwos.map" "/o$FULL_HEX" \
        "$ROOT_DIR/src/18F87K22_hwos.lkr" "${objects[@]}"
)

# TinyBld must not receive the logo/program area beginning at 0x1E000.
printf 'CROP %s\n' "${TINY_HEX#"$ROOT_DIR/"}"
"$SREC_CAT" "$FULL_HEX" -Intel -crop 0x00000 0x1E000 -o "$TINY_HEX" -Intel

if [[ ! -s "$TINY_HEX" ]] || ! grep -q '^:00000001FF' "$TINY_HEX"; then
    printf 'error: generated upload HEX is empty or has no Intel HEX EOF record: %s\n' "$TINY_HEX" >&2
    exit 1
fi

FULL_HEX_SHA256=$(sha256sum "$FULL_HEX" | awk '{print $1}')
TINY_HEX_SHA256=$(sha256sum "$TINY_HEX" | awk '{print $1}')

{
    printf 'source_commit=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
    printf 'processor=%s\n' "$PROCESSOR"
    printf 'full_hex_sha256=%s\n' "$FULL_HEX_SHA256"
    printf 'upload_hex_sha256=%s\n' "$TINY_HEX_SHA256"
} > "$BUILD_DIR/build-info.txt"

printf '\nUpload artefact: %s\n' "$TINY_HEX"
printf 'Build metadata:  %s\n' "$BUILD_DIR/build-info.txt"
