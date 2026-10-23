#!/usr/bin/env bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# Checks a built APK. Run from any folder, in Git Bash:
#   scripts/check_apk.sh [path-to-apk]        (default: build/forkline-debug.apk)
#
# It prints everything the APK bundles, the Java packages and native libraries
# inside it, and the permissions in its manifest. It then checks that:
#   1. the APK requests no permissions at all;
#   2. only arm64-v8a native code is inside;
#   3. LICENSE and NOTICE are inside, and tools, tests, docs, prototypes and
#      scripts are not;
#   4. every bundled third party part is credited in NOTICE and README.md.
# Exit code 0 means every check passed. 1 means a permission, a missing or
# wrong file, or a missing tool. 2 means a bundled part is not credited.
#
# Needs aapt2 and dexdump from the Android SDK build-tools (C:\Android\Sdk, or
# set ANDROID_SDK), and unzip.

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apk="${1:-$root/build/forkline-debug.apk}"
sdk="${ANDROID_SDK:-C:/Android/Sdk}"
failed=0
uncredited=0
missing=""

if [ ! -f "$apk" ]; then
	echo "There is no APK at $apk. Build it first: scripts/build.sh"
	exit 1
fi
apk="$(cd "$(dirname "$apk")" && pwd)/$(basename "$apk")"
tools_dir="$(ls -d "$sdk"/build-tools/* 2> /dev/null | sort -V | tail -n 1)"
aapt2="$tools_dir/aapt2.exe"
dexdump="$tools_dir/dexdump.exe"
[ -f "$aapt2" ] || aapt2="$tools_dir/aapt2"
[ -f "$dexdump" ] || dexdump="$tools_dir/dexdump"
if [ -z "$tools_dir" ] || [ ! -f "$aapt2" ] || [ ! -f "$dexdump" ]; then
	echo "aapt2 and dexdump were not found in $sdk/build-tools. Install Android SDK Build-Tools, or set ANDROID_SDK."
	exit 1
fi
if ! command -v unzip > /dev/null 2>&1; then
	echo "unzip was not found. Run this in Git Bash."
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "APK: $apk"
echo
echo "== Everything the APK bundles (unzip -l) =="
unzip -l "$apk"

entries="$(unzip -Z1 "$apk")"

echo
echo "== Native libraries =="
libs="$(printf '%s\n' "$entries" | grep '^lib/' || true)"
printf '%s\n' "$libs"
if printf '%s\n' "$libs" | grep -v '^lib/arm64-v8a/' | grep -q .; then
	echo "FAIL: native code for another architecture is inside. Only arm64-v8a is allowed."
	failed=1
fi

echo
echo "== Files that must not be inside =="
leaked="$(printf '%s\n' "$entries" | grep -E '^assets/(tools|tests|docs|prototypes|scripts)/' || true)"
if [ -n "$leaked" ]; then
	printf '%s\n' "$leaked"
	echo "FAIL: left-out folders are inside the APK."
	failed=1
else
	echo "None of tools/, tests/, docs/, prototypes/, scripts/ is inside."
fi
for f in assets/LICENSE assets/NOTICE; do
	if printf '%s\n' "$entries" | grep -qx "$f"; then
		echo "$f is inside."
	else
		echo "FAIL: $f is missing from the APK."
		failed=1
	fi
done

echo
echo "== Permissions in the manifest =="
perm_out="$("$aapt2" dump permissions "$apk" 2> /dev/null | tr -d '\r')"
perm_rc=$?
perm_lines="$(printf '%s\n' "$perm_out" | grep -v '^package:' | grep -v '^$' || true)"
manifest_perms="$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk" 2> /dev/null | tr -d '\r' | grep -E 'E: (uses-permission|permission)' || true)"
if [ "$perm_rc" -ne 0 ]; then
	echo "FAIL: aapt2 could not read the manifest."
	failed=1
elif [ -n "$perm_lines" ] || [ -n "$manifest_perms" ]; then
	printf '%s\n' "$perm_lines"
	printf '%s\n' "$manifest_perms"
	echo "FAIL: the APK requests permissions. Forkline must request none."
	failed=1
else
	echo "None. The APK requests no permissions."
fi

echo
echo "== Java packages defined in classes*.dex (class count, package) =="
mkdir -p "$work/dex"
if ! unzip -oq "$apk" 'classes*.dex' -d "$work/dex" || ! ls "$work"/dex/classes*.dex > /dev/null 2>&1; then
	echo "FAIL: no classes*.dex could be extracted from the APK, so its Java packages cannot be checked."
	exit 1
fi
descriptors="$("$dexdump" -f "$work"/dex/classes*.dex | tr -d '\r' | grep 'Class descriptor' | sed "s/.*'L\(.*\);'.*/\1/")"
if [ -z "$descriptors" ]; then
	echo "FAIL: dexdump read no classes from the APK, so its Java packages cannot be checked."
	exit 1
fi
# Group by the first two path segments, or one for names like "kotlin/...".
roots="$(printf '%s\n' "$descriptors" | awk -F/ '
	{
		if ($1 == "org" || $1 == "com" || $1 == "net" || $1 == "io" || $1 == "android") { print $1 "/" $2 } else { print $1 }
	}' | sort | uniq -c | sort -rn)"
printf '%s\n' "$roots"

# Maps a package root or library file to a label and the word NOTICE must use.
credit_for() {
	case "$1" in
		org/godotengine|com/godot|libgodot_android.so) echo "Godot Engine|Godot Engine" ;;
		androidx|android/support) echo "AndroidX (Android Open Source Project)|AndroidX" ;;
		kotlin) echo "Kotlin standard library (JetBrains)|Kotlin" ;;
		kotlinx) echo "kotlinx.coroutines (JetBrains)|kotlinx.coroutines" ;;
		org/jetbrains|org/intellij) echo "JetBrains Java Annotations|JetBrains" ;;
		org/jspecify) echo "JSpecify annotations|JSpecify" ;;
		com/google) echo "Google Guava ListenableFuture|Guava" ;;
		libc++_shared.so) echo "LLVM libc++|libc++" ;;
		*) echo "UNKNOWN|" ;;
	esac
}

echo
echo "== Bundled third party parts, compared with NOTICE and README.md =="
parts="$(printf '%s\n' "$roots" | awk '{ print $2 }'; printf '%s\n' "$libs" | sed 's|.*/||' | grep .)"
printf '%-28s %-44s %-8s %s\n' "package or file" "part" "NOTICE" "README.md"
while IFS= read -r part; do
	[ -n "$part" ] || continue
	entry="$(credit_for "$part")"
	label="${entry%%|*}"
	word="${entry##*|}"
	in_notice="no"
	in_readme="no"
	if [ -n "$word" ]; then
		grep -qi -- "$word" "$root/NOTICE" 2> /dev/null && in_notice="yes"
		grep -qi -- "$word" "$root/README.md" 2> /dev/null && in_readme="yes"
	fi
	printf '%-28s %-44s %-8s %s\n' "$part" "$label" "$in_notice" "$in_readme"
	if [ "$in_notice" != "yes" ] || [ "$in_readme" != "yes" ]; then
		uncredited=1
		missing="$missing$part"$'\n'
	fi
done <<< "$parts"
if [ -n "$missing" ]; then
	echo
	echo "Not credited in both files. The classes inside these packages:"
	while IFS= read -r part; do
		[ -n "$part" ] || continue
		printf '%s\n' "$descriptors" | grep "^$part/" | sed 's/^/  /'
	done <<< "$missing"
fi
echo
echo "The About screen must list the same parts. It does not exist yet, so check it by hand once it does."

echo
if [ "$failed" -ne 0 ]; then
	echo "RESULT: FAILED. Read the FAIL lines above."
	exit 1
fi
if [ "$uncredited" -ne 0 ]; then
	echo "RESULT: a bundled part is not credited in NOTICE and README.md (see the table). Ask the DM to update NOTICE, README and About."
	exit 2
fi
echo "RESULT: OK. No permissions, arm64-v8a only, every bundled part is credited."
