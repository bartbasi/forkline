#!/usr/bin/env bash
# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Renders the theme slice screenshots into docs/art. Run from anywhere:
#     bash prototypes/theme/screenshots.sh
# Each run opens a Godot window briefly, saves one PNG and quits.
set -euo pipefail
cd "$(dirname "$0")/../.."
SCENE=res://prototypes/theme/slice.tscn
OUT=res://docs/art

shot() {
	local size="$1"
	shift
	timeout 120 godot --path . --resolution "$size" "$SCENE" -- "$@" 2>&1 | grep -E "Saved|Slice layout|ERROR|SCRIPT ERROR" || true
}

shot 540x1200 --shot=$OUT/slice_portrait.png
shot 540x1200 --shot=$OUT/slice_portrait_build.png --build
shot 540x1200 --shot=$OUT/slice_font_system.png --font=system
shot 540x1200 --shot=$OUT/slice_font_both.png --font=both
shot 906x1088 --shot=$OUT/slice_fold_inner.png
shot 1280x720 --shot=$OUT/slice_wide.png
shot 540x960 --shot=$OUT/store_screenshot_1.png --caption
shot 1200x1000 --sheet=$OUT/silhouettes.png
shot 512x512 --icon=$OUT/icon_512.png
