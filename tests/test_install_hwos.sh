#!/usr/bin/env bash
# Exercise the installer safety checks without a Windows builder or a device.
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hwos-install-test.XXXXXX")
trap 'rm -rf -- "$TEMP_DIR"' EXIT

fail() {
	printf 'test failure: %s\n' "$*" >&2
	exit 1
}

mkdir -p "$TEMP_DIR/tools"
cp "$ROOT_DIR/Makefile" "$TEMP_DIR/Makefile"
cp "$ROOT_DIR/tools/install_hwos.sh" "$TEMP_DIR/tools/install_hwos.sh"

cat > "$TEMP_DIR/tools/build_hwos.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
commit=$(git -C "$root" rev-parse HEAD)
branch=$(git -C "$root" symbolic-ref --short HEAD)
safe_branch=$(printf '%s' "$branch" | sed 's/[^A-Za-z0-9._-]\+/-/g')
package_name="hwos_ostc3_${safe_branch}_${commit:0:12}_firmware.hex"
artifact_dir="$root/build/windows/$commit"
mkdir -p "$artifact_dir"
printf 'test full firmware\n' > "$artifact_dir/hwos.production.hex"
printf 'test package\n' > "$artifact_dir/$package_name"
full_hash=$(sha256sum "$artifact_dir/hwos.production.hex" | awk '{print $1}')
package_hash=$(sha256sum "$artifact_dir/$package_name" | awk '{print $1}')
cat > "$artifact_dir/build-info.txt" <<INFO
source_commit=$commit
source_branch=$branch
ostc3_package=$package_name
full_hex_sha256=$full_hash
ostc3_package_input_sha256=$full_hash
ostc3_package_sha256=$package_hash
INFO
EOF
chmod +x "$TEMP_DIR/tools/build_hwos.sh"

cat > "$TEMP_DIR/mock-downloader" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${DOWNLOADER_ARGS:?}"
EOF
chmod +x "$TEMP_DIR/mock-downloader"

git -C "$TEMP_DIR" init --quiet --initial-branch installer-test
git -C "$TEMP_DIR" config user.name 'Installer test'
git -C "$TEMP_DIR" config user.email installer-test@example.invalid
git -C "$TEMP_DIR" add Makefile tools mock-downloader
git -C "$TEMP_DIR" commit --quiet -m 'test fixture'

[[ -z "$(git -C "$TEMP_DIR" remote)" ]] || fail 'fixture must have no remote or release-validation tags'
DOWNLOADER_ARGS="$TEMP_DIR/downloader-args" \
	make --no-print-directory -C "$TEMP_DIR" install \
		DEVICE=AA:BB:CC:DD:EE:FF \
		FIRMWARE_INSTALLER="$TEMP_DIR/mock-downloader" > /dev/null

grep -Fx -- '--update-firmware' "$TEMP_DIR/downloader-args" >/dev/null || fail 'missing update-firmware argument'
grep -Fx -- '--dc-vendor=Heinrichs Weikamp' "$TEMP_DIR/downloader-args" >/dev/null || fail 'missing legacy vendor argument'
grep -Fx -- '--dc-product=OSTC 3' "$TEMP_DIR/downloader-args" >/dev/null || fail 'missing legacy OSTC 3 product argument'
grep -Fx -- '--device=AA:BB:CC:DD:EE:FF' "$TEMP_DIR/downloader-args" >/dev/null || fail 'missing explicit device argument'
grep -F -- '--firmware-file=' "$TEMP_DIR/downloader-args" >/dev/null || fail 'missing package argument'

printf 'installer test: pass\n'
