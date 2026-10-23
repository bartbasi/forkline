#!/usr/bin/env bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# Builds the debug APK: build/forkline-debug.apk
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
want_version="4.7.2.stable"

if ! command -v "$godot" > /dev/null 2>&1; then
	echo "Godot was not found as '$godot'. Install Godot $want_version or set GODOT to the full path of its exe."
	exit 1
fi

version="$("$godot" --version | tr -d '\r' | tail -n 1)"
case "$version" in
	"$want_version"*) echo "Godot $version" ;;
	*) echo "This project needs Godot $want_version, but '$godot' is version '$version'."; exit 1 ;;
esac

echo "Importing the project..."
if ! "$godot" --headless --path "$root" --import; then
	echo "The import failed. Read the Godot output above."
	exit 1
fi

mkdir -p "$root/build"
rm -f "$apk"

echo "Exporting the debug APK..."
if ! "$godot" --headless --path "$root" --export-debug "Android" "$apk" || [ ! -f "$apk" ]; then
	echo "The export failed. Read the Godot output above."
	exit 1
fi

size_mb="$(( $(wc -c < "$apk") / 1048576 ))"
echo "Built $apk (about $size_mb MB)"
echo "Check it with: scripts/check_apk.sh"
echo "Install it with: scripts/install.sh"
