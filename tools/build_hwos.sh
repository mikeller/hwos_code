#!/usr/bin/env bash
# Build the current pushed hwOS commit on the authorised Windows C18 builder.
#
# This script never pushes. It creates a detached, per-commit worktree on the
# builder, invokes tools/build_hwos.ps1 there, verifies copied artefacts against
# build-info.txt, then removes only the worktree it created.
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly GIT_REMOTE=${GIT_REMOTE:-origin}

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

REMOTE_BUILD_CONFIG=${REMOTE_BUILD_CONFIG:-"$ROOT_DIR/tools/build_hwos.remote.conf"}
if [[ "$REMOTE_BUILD_CONFIG" != /* ]]; then
	REMOTE_BUILD_CONFIG="$ROOT_DIR/$REMOTE_BUILD_CONFIG"
fi
[[ -f "$REMOTE_BUILD_CONFIG" ]] || fail "Windows builder configuration is missing: $REMOTE_BUILD_CONFIG; copy tools/build_hwos.remote.conf.example and set its values"
[[ -O "$REMOTE_BUILD_CONFIG" ]] || fail "refusing to source Windows builder configuration not owned by the current user: $REMOTE_BUILD_CONFIG"
# shellcheck disable=SC1090
source "$REMOTE_BUILD_CONFIG"
for setting in WINDOWS_BUILDER WINDOWS_REPO WINDOWS_WORKTREE_ROOT; do
	value=${!setting:-}
	[[ -n "$value" ]] || fail "Windows builder configuration must set $setting: $REMOTE_BUILD_CONFIG"
	[[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail "Windows builder configuration contains a newline in $setting"
done
[[ "$WINDOWS_BUILDER" != *[[:space:]]* ]] || fail "WINDOWS_BUILDER must not contain whitespace: $REMOTE_BUILD_CONFIG"
[[ "$WINDOWS_REPO" =~ ^[A-Za-z]:/ ]] || fail "WINDOWS_REPO must be an absolute Windows path using forward slashes: $REMOTE_BUILD_CONFIG"
[[ "$WINDOWS_WORKTREE_ROOT" =~ ^[A-Za-z]:/ ]] || fail "WINDOWS_WORKTREE_ROOT must be an absolute Windows path using forward slashes: $REMOTE_BUILD_CONFIG"
readonly REMOTE_BUILD_CONFIG WINDOWS_BUILDER WINDOWS_REPO WINDOWS_WORKTREE_ROOT

ps_quote() {
	printf "%s" "$1" | sed "s/'/''/g"
}

run_remote_powershell() {
	local script=$1
	local encoded
	encoded=$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')
	ssh -o BatchMode=yes "$WINDOWS_BUILDER" \
		powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded"
}

remote_copy() {
	local remote_path=$1
	scp -p -- "${WINDOWS_BUILDER}:${remote_path}" "$ARTIFACT_DIR/"
}

metadata_value() {
	local key=$1
	local info_file=${2:-"$ARTIFACT_DIR/build-info.txt"}
	awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit }' "$info_file"
}

hash_matches() {
	local file=$1
	local expected=$2
	[[ -n "$expected" && -s "$file" ]] || return 1
	[[ "$(sha256sum "$file" | awk '{print $1}')" == "$expected" ]]
}

verify_hash() {
	local file=$1
	local expected=$2
	local actual
	[[ -n "$expected" ]] || fail "build metadata has no hash for $(basename -- "$file")"
	[[ -s "$file" ]] || fail "copied artefact is missing or empty: $file"
	actual=$(sha256sum "$file" | awk '{print $1}')
	[[ "$actual" == "$expected" ]] || fail "SHA-256 mismatch for $(basename -- "$file"): expected $expected, got $actual"
}

artifact_set_is_verified() {
	local directory=$1
	local expected_commit=$2
	local expected_package=$3
	local info_file="$directory/build-info.txt"
	local package package_name

	[[ -f "$info_file" ]] || return 1
	[[ "$(metadata_value source_commit "$info_file")" == "$expected_commit" ]] || return 1
	hash_matches "$directory/hwos.production.hex" "$(metadata_value full_hex_sha256 "$info_file")" || return 1
	hash_matches "$directory/hwos_tiny.hex" "$(metadata_value upload_hex_sha256 "$info_file")" || return 1
	[[ -s "$directory/hwos.map" ]] || return 1
	package=$(metadata_value ostc3_package "$info_file")
	[[ -n "$package" && "$package" != not_created_build_only ]] || return 1
	package_name=${package//\\//\/}
	package_name=$(basename -- "$package_name")
	[[ "$package_name" == "$expected_package" ]] || return 1
	hash_matches "$directory/$package_name" "$(metadata_value ostc3_package_sha256 "$info_file")" || return 1
}

cd "$ROOT_DIR"
[[ -z "$(git status --porcelain)" ]] || fail 'refusing to build uncommitted local changes; commit and push them first'

BRANCH=$(git symbolic-ref --quiet --short HEAD) || fail 'refusing to build a detached HEAD; check out the pushed branch to build'
COMMIT=$(git rev-parse HEAD)
REMOTE_REF="refs/heads/$BRANCH"
REMOTE_COMMIT=$(git ls-remote --exit-code "$GIT_REMOTE" "$REMOTE_REF" | awk '{print $1}') || \
	fail "branch '$BRANCH' is not available from remote '$GIT_REMOTE'; push it before building"
[[ "$REMOTE_COMMIT" == "$COMMIT" ]] || fail "local $BRANCH ($COMMIT) does not match $GIT_REMOTE/$BRANCH ($REMOTE_COMMIT); push the exact commit before building"
SAFE_BRANCH=$(printf '%s' "$BRANCH" | sed 's/[^A-Za-z0-9._-]\+/-/g')
[[ -n "$SAFE_BRANCH" ]] || fail "cannot derive a safe package name from branch: $BRANCH"
PACKAGE_NAME="hwos_ostc3_${SAFE_BRANCH}_${COMMIT:0:12}_UNVALIDATED_firmware.hex"

FINAL_ARTIFACT_DIR=${ARTIFACT_DIR:-"$ROOT_DIR/build/windows/$COMMIT"}
if [[ "$FINAL_ARTIFACT_DIR" != /* ]]; then
	FINAL_ARTIFACT_DIR="$ROOT_DIR/$FINAL_ARTIFACT_DIR"
fi
readonly FINAL_ARTIFACT_DIR
ARTIFACT_PARENT=$(dirname -- "$FINAL_ARTIFACT_DIR")
mkdir -p "$ARTIFACT_PARENT"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
if [[ -e "$FINAL_ARTIFACT_DIR" ]]; then
	if artifact_set_is_verified "$FINAL_ARTIFACT_DIR" "$COMMIT" "$PACKAGE_NAME"; then
		printf 'Verified Windows build artefacts already exist: %s\n' "$FINAL_ARTIFACT_DIR"
		exit 0
	fi
	FAILED_ARTIFACT_DIR="$ARTIFACT_PARENT/failed-${COMMIT:0:12}-$RUN_ID"
	mv -- "$FINAL_ARTIFACT_DIR" "$FAILED_ARTIFACT_DIR"
	printf 'Preserved incomplete artefacts for diagnosis: %s\n' "$FAILED_ARTIFACT_DIR" >&2
fi

ARTIFACT_DIR=$(mktemp -d "$ARTIFACT_PARENT/.staging-${COMMIT:0:12}.XXXXXX")
preserve_failed_staging() {
	local result=$?
	if [[ $result -ne 0 && -n "${ARTIFACT_DIR:-}" && -d "$ARTIFACT_DIR" ]]; then
		printf 'Build attempt failed with exit code %d. Diagnostic staging is retained: %s\n' "$result" "$ARTIFACT_DIR" > "$ARTIFACT_DIR/failure.log"
		printf 'Diagnostic staging retained: %s\n' "$ARTIFACT_DIR" >&2
	fi
}
trap preserve_failed_staging EXIT

REMOTE_WORKTREE="${WINDOWS_WORKTREE_ROOT%/}/${COMMIT}-${RUN_ID}"
readonly REMOTE_WORKTREE
remote_setup_script=$(cat <<EOF
\$ErrorActionPreference = 'Stop'
\$repo = '$(ps_quote "$WINDOWS_REPO")'
\$worktree = '$(ps_quote "$REMOTE_WORKTREE")'
\$commit = '$(ps_quote "$COMMIT")'
\$branch = '$(ps_quote "$BRANCH")'
\$remoteRef = '$(ps_quote "$REMOTE_REF")'
if (-not (Test-Path -LiteralPath \$repo -PathType Container)) { throw "Windows repository is missing: \$repo" }
if (Test-Path -LiteralPath \$worktree) { throw "refusing to reuse existing builder worktree: \$worktree" }
& git -C \$repo status --porcelain | ForEach-Object { throw "refusing to alter non-clean Windows checkout \${repo}: \$_" }
& git -C \$repo fetch --no-tags origin \$remoteRef
if (\$LASTEXITCODE -ne 0) { throw 'git fetch failed' }
\$fetched = (& git -C \$repo rev-parse FETCH_HEAD).Trim()
if (\$fetched -ne \$commit) { throw "fetched \$remoteRef is \$fetched, expected \$commit" }
New-Item -ItemType Directory -Path (Split-Path -Parent \$worktree) -Force | Out-Null
& git -C \$repo worktree add --detach \$worktree \$commit
if (\$LASTEXITCODE -ne 0) { throw 'git worktree add failed' }
try {
    & (Join-Path \$worktree 'tools\\build_hwos.ps1') -Ostc3Package '$PACKAGE_NAME' -SourceBranch \$branch
    if (\$LASTEXITCODE -ne 0) { throw 'Windows firmware build failed' }
    \$info = Join-Path \$worktree 'build\\build-info.txt'
    if (-not (Test-Path -LiteralPath \$info -PathType Leaf)) { throw "missing build metadata: \$info" }
    \$sourceCommit = ((Get-Content -LiteralPath \$info) | Where-Object { \$_ -like 'source_commit=*' } | Select-Object -First 1).Substring('source_commit='.Length)
    if (\$sourceCommit -ne \$commit) { throw "build metadata records \$sourceCommit, expected \$commit" }
    \$sourceBranch = ((Get-Content -LiteralPath \$info) | Where-Object { \$_ -like 'source_branch=*' } | Select-Object -First 1).Substring('source_branch='.Length)
    if (\$sourceBranch -ne \$branch) { throw "build metadata records branch \$sourceBranch, expected \$branch" }
} catch {
    Write-Warning "Builder worktree retained for diagnosis: \$worktree"
    throw
}
Write-Output "REMOTE_WORKTREE=\$worktree"
EOF
)

printf 'Building %s (%s) on %s\n' "$BRANCH" "$COMMIT" "$WINDOWS_BUILDER"
run_remote_powershell "$remote_setup_script" |& tee "$ARTIFACT_DIR/remote-build.log"

cleanup_remote_worktree() {
	local cleanup_script
	cleanup_script=$(cat <<EOF
\$ErrorActionPreference = 'Stop'
\$repo = '$(ps_quote "$WINDOWS_REPO")'
\$worktree = '$(ps_quote "$REMOTE_WORKTREE")'
& git -C \$repo worktree remove --force \$worktree
if (\$LASTEXITCODE -ne 0) { throw "could not remove builder worktree: \$worktree" }
EOF
)
	run_remote_powershell "$cleanup_script"
}

remote_copy "$REMOTE_WORKTREE/build/build-info.txt"
[[ "$(metadata_value source_commit)" == "$COMMIT" ]] || fail 'copied build metadata does not identify the requested source commit'
[[ "$(metadata_value source_branch)" == "$BRANCH" ]] || fail 'copied build metadata does not identify the requested source branch'

remote_copy "$REMOTE_WORKTREE/build/hwos.production.hex"
remote_copy "$REMOTE_WORKTREE/build/hwos_tiny.hex"
remote_copy "$REMOTE_WORKTREE/build/hwos.map"
verify_hash "$ARTIFACT_DIR/hwos.production.hex" "$(metadata_value full_hex_sha256)"
verify_hash "$ARTIFACT_DIR/hwos_tiny.hex" "$(metadata_value upload_hex_sha256)"
[[ -s "$ARTIFACT_DIR/hwos.map" ]] || fail 'copied linker map is missing or empty'

REMOTE_PACKAGE=$(metadata_value ostc3_package)
[[ -n "$REMOTE_PACKAGE" && "$REMOTE_PACKAGE" != not_created_build_only ]] || \
	fail 'build metadata does not record the requested OSTC3 package'
REMOTE_PACKAGE_NAME=${REMOTE_PACKAGE//\\//\/}
REMOTE_PACKAGE_NAME=$(basename -- "$REMOTE_PACKAGE_NAME")
[[ "$REMOTE_PACKAGE_NAME" == "$PACKAGE_NAME" ]] || \
	fail "build metadata records package $REMOTE_PACKAGE_NAME, expected $PACKAGE_NAME"
remote_copy "${REMOTE_PACKAGE//\\//\/}"
verify_hash "$ARTIFACT_DIR/$REMOTE_PACKAGE_NAME" "$(metadata_value ostc3_package_sha256)"

cleanup_remote_worktree
printf 'source_commit=%s\n' "$COMMIT" > "$ARTIFACT_DIR/.verified"
mv -- "$ARTIFACT_DIR" "$FINAL_ARTIFACT_DIR"
printf 'Verified Windows build artefacts: %s\n' "$FINAL_ARTIFACT_DIR"
