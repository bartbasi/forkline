#!/usr/bin/env bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# Builds the debug APK: build/forkline-debug.apk
# Works from a fresh clone or worktree in one command. It imports the project
# itself (retrying a crashed import), exports with a private temp folder, and
# only reports success when a new, readable APK exists. Any failure exits 1.
#
# Run from any folder, in Git Bash:
#   scripts/build.sh
#
# Godot 4.7.2 must be on PATH as "godot", or set the GODOT environment variable
# to the full path of the Godot exe. The Android SDK, the JDK and the debug
# keystore come from Godot's Editor Settings, never from this repo.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot="${GODOT:-godot}"
apk="$root/build/forkline-debug.apk"
class_cache="$root/.godot/global_script_class_cache.cfg"
want_version="4.7.2.stable"
attempts=3
started="$(date +%s)"

fail() {
	echo "BUILD FAILED: $1"
	exit 1
}

for tool in timeout unzip; do
	command -v "$tool" > /dev/null 2>&1 || fail "'$tool' was not found. Run this script in Git Bash."
done
command -v "$godot" > /dev/null 2>&1 || fail "Godot was not found as '$godot'. Install Godot $want_version or set GODOT to the full path of its exe."

version="$("$godot" --version | tr -d '\r' | tail -n 1)"
case "$version" in
	"$want_version"*) echo "Godot $version" ;;
	*) fail "This project needs Godot $want_version, but '$godot' is version '$version'." ;;
esac

# Import until Godot has written its class cache. The first import of a fresh
# project can crash or stop early, and a rerun finishes the job.
echo "Importing the project..."
imported=0
for n in $(seq 1 "$attempts"); do
	rm -f "$class_cache"
	code=0
	timeout 300 "$godot" --headless --path "$root" --import || code=$?
	if [ "$code" -eq 0 ] && [ -s "$class_cache" ]; then
		imported=1
		break
	fi
	echo "Import attempt $n of $attempts did not finish (exit code $code)."
done
[ "$imported" -eq 1 ] || fail "the import did not finish after $attempts attempts. Read the Godot output above."

# Godot names its temporary export files with the clock in whole seconds, in the
# shared temp folder. Two exports that start in the same second (another Godot
# project, or a second copy of this script) overwrite each other's files. A
# private temp folder for this build stops that.
mkdir -p "$root/build"
export_tmp="$(mktemp -d "$root/build/tmp.XXXXXX")"
trap 'rm -rf "$export_tmp"' EXIT
export_tmp_native="$(cygpath -w "$export_tmp" 2> /dev/null || echo "$export_tmp")"

echo "Exporting the debug APK..."
built=0
for n in $(seq 1 "$attempts"); do
	rm -f "$apk" "$apk.idsig"
	code=0
	TEMP="$export_tmp_native" TMP="$export_tmp_native" TMPDIR="$export_tmp" \
		timeout 600 "$godot" --headless --path "$root" --export-debug "Android" "$apk" || code=$?
	# A good APK: Godot exited 0, the file is new, over 1 MB, and a valid zip.
	if [ "$code" -eq 0 ] && [ -f "$apk" ] \
		&& [ "$(stat -c %Y "$apk")" -ge "$started" ] \
		&& [ "$(wc -c < "$apk")" -gt 1048576 ] \
		&& unzip -tq "$apk" > /dev/null 2>&1; then
		built=1
		break
	fi
	echo "Export attempt $n of $attempts failed (exit code $code)."
	rm -f "$apk"
done
[ "$built" -eq 1 ] || fail "the export did not produce a good APK after $attempts attempts. Read the Godot output above."

size_mb="$(( $(wc -c < "$apk") / 1048576 ))"
echo "Built $apk (about $size_mb MB)"
echo "Check it with: scripts/check_apk.sh"
echo "Install it with: scripts/install.sh"
