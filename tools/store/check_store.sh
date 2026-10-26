#!/usr/bin/env bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# Checks the Google Play material in docs/store/:
#   - the listing's character counts (stated and real) against Google's limits
#   - plain ASCII only (no em dashes, no curly quotes) in the listing and policy
#   - no double hyphens in the prose, outside code fences
#   - the required wording is in the full description and the policy
#   - the image files exist and have the sizes Play needs
# Run from anywhere:  bash tools/store/check_store.sh
# Exit 0 when everything passes, 1 otherwise.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

LISTING=docs/store/listing.md
POLICY=docs/store/privacy-policy.md
GFX=docs/store/graphics
failed=0

fail() { echo "FAIL: $*"; failed=$((failed + 1)); }
ok() { echo "ok:   $*"; }

# The text of the first fenced block under the heading that starts with $1.
block_after() {
	awk -v h="$1" '
		index($0, h) == 1 { inh = 1; next }
		inh && /^```/ { if (!infence) { infence = 1; next } else { exit } }
		inh && infence { print }
	' "$LISTING"
}

# The "Characters: N of L." line under the heading.
stated_after() {
	awk -v h="$1" '
		index($0, h) == 1 { inh = 1; next }
		inh && /^Characters: / { print; exit }
	' "$LISTING"
}

check_field() {
	local heading="$1" limit="$2" text count line stated
	if [ ! -f "$LISTING" ]; then fail "$LISTING is missing"; return; fi
	text="$(block_after "$heading")"
	if [ -z "$text" ]; then fail "no text found under '$heading'"; return; fi
	count=${#text}
	line="$(stated_after "$heading")"
	stated="$(echo "$line" | sed -n 's/^Characters: \([0-9]*\) of \([0-9]*\)\.$/\1/p')"
	if [ "$count" -gt "$limit" ]; then
		fail "$heading: $count characters, limit $limit"
	elif [ "$stated" != "$count" ]; then
		fail "$heading: the listing says '${line:-nothing}' but the text has $count characters"
	else
		ok "$heading: $count of $limit"
	fi
}

check_field "## App name" 30
check_field "## Short description" 80
check_field "## Full description" 4000
check_field "## What's new" 500

# Plain ASCII, and no double hyphens in prose.
check_text() {
	local file="$1"
	if [ ! -f "$file" ]; then fail "$file is missing"; return; fi
	if LC_ALL=C grep -n -P '[^\x00-\x7F]' "$file" >/dev/null; then
		fail "$file has characters outside plain ASCII:"
		LC_ALL=C grep -n -P '[^\x00-\x7F]' "$file" | head -5
	else
		ok "$file is plain ASCII"
	fi
	if awk '/^```/ { f = !f; next } !f && !/^[|: -]+$/ && /--/ { print FILENAME ":" NR ": " $0; bad = 1 } END { exit bad }' "$file"; then
		ok "$file has no double hyphens in prose"
	else
		fail "$file has a double hyphen in prose (shown above)"
	fi
}
check_text "$LISTING"
check_text "$POLICY"

# Required wording.
need() {
	local file="$1" phrase="$2"
	if grep -q -i -F "$phrase" "$file" 2>/dev/null; then ok "$file has '$phrase'"; else fail "$file lacks '$phrase'"; fi
}
for phrase in "no ads" "no in-app purchases" "no accounts" "no tracking" "fully offline" "free software under the GNU GPL version 3" "github.com/bartbasi/forkline"; do
	need "$LISTING" "$phrase"
done
for phrase in "Play, Inc." "Copyright 2026 Play, Inc." "bartbasi@gmail.com" "buymeacoffee.com" "github.com/bartbasi/forkline" "Send feedback" "no Android permissions"; do
	need "$POLICY" "$phrase"
done

# Image sizes, read from the PNG header (width and height are at bytes 16 to 23).
png_dim() {
	od -An -t u1 -j "$2" -N 4 "$1" | awk '{ print $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 }'
}
check_png() {
	local f="$GFX/$1" want_w="$2" want_h="$3" sig w h bytes
	if [ ! -f "$f" ]; then fail "$f is missing"; return; fi
	sig="$(od -An -t x1 -N 8 "$f" | tr -d ' \n')"
	if [ "$sig" != "89504e470d0a1a0a" ]; then fail "$f is not a PNG"; return; fi
	w="$(png_dim "$f" 16)"
	h="$(png_dim "$f" 20)"
	bytes=$(wc -c < "$f")
	if [ "$w" != "$want_w" ] || [ "$h" != "$want_h" ]; then
		fail "$f is $w x $h, wanted $want_w x $want_h"
	elif [ "$bytes" -gt 8388608 ]; then
		fail "$f is $bytes bytes, over Play's limit"
	else
		ok "$f is $want_w x $want_h, $bytes bytes"
	fi
}
check_png icon_512.png 512 512
check_png feature_1024x500.png 1024 500
for n in screen_1_front_door screen_2_modes screen_3_levels screen_4_build_phase screen_5_wave; do
	check_png "$n.png" 1080 2160
done

if [ "$failed" -gt 0 ]; then
	echo "STORE CHECK FAILED: $failed problem(s)"
	exit 1
fi
echo "Store check passed."
