# Release and build notes

Forkline is built with Godot 4.7.2 (standard build). Run everything from Git Bash unless a step says PowerShell.

## Build the debug APK

From the repo root, in a fresh clone or a fresh `git worktree`, one command does it all:

```bash
bash scripts/build.sh
```

PowerShell does the same:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build.ps1
```

The script:

1. Checks that Godot is version 4.7.2.stable. It uses `godot` on PATH, or the GODOT environment variable.
2. Imports the project. The first import of a fresh project can crash or stop early, so the script reruns it (up to 3 tries) until `.godot/global_script_class_cache.cfg` exists. You do not run the import yourself.
3. Exports `build/forkline-debug.apk` with a private temp folder (`build/tmp.*`, removed afterwards). It retries a failed export up to 3 times.
4. Counts the build as good only when Godot exited 0 and the APK is new, over 1 MB and a valid zip.

On any failure it prints `BUILD FAILED: ...` and exits 1. It never reports success without an APK. If you pipe the output (for example to `tail`), check the exit code too: use `set -o pipefail`, or look for the `Built` line.

Each Godot import and export is limited by a timeout (300 s and 600 s).

## Why the private temp folder

Godot writes its temporary export files to the shared temp folder, named with the clock in whole seconds (`tmpexport-unaligned.<unix seconds>.apk`). Two exports that start in the same second overwrite each other, and one fails with "Could not unzip temporary unaligned APK". Other Godot projects on this machine, or two builds of Forkline at once, can hit this. Pointing TEMP and TMP at a folder inside `build/` for the export step avoids it. The retry covers any other one-off failure.

## Build in a fresh worktree

```bash
git worktree add --detach "$TEMP/fl_try" HEAD
cd "$TEMP/fl_try"
bash scripts/build.sh
```

Then clean up:

```bash
cd /path/to/forkline
git worktree remove --force "$TEMP/fl_try"
git worktree prune
```

A worktree has only what is committed. Commit script changes first, or the build uses the old script.

## Check and install

```bash
bash scripts/check_apk.sh     # bundled parts, credits, no permissions
bash scripts/install.sh       # needs exactly one ready phone on USB
```

PowerShell has `scripts\install.ps1`.

## Check a release APK

```bash
bash scripts/check_apk.sh --release path/to/forkline-release.apk
```

`--release` adds two checks. First, `android:debuggable` must be absent or an explicit false (`=false` or `(type 0x12)0x0`). True, `0x1`, a reference or any other value fails. Second, the APK must not be signed with the Android debug certificate (`CN=Android Debug`). The signer is read with `apksigner` (SDK build-tools, or on PATH), or else `keytool` (on PATH or in `JAVA_HOME`). If neither is found, the check fails instead of passing. The debug APK is debuggable and debug-signed on purpose, so the default mode only prints notes. Play also refuses debuggable uploads. Release signing is ask first, so no release APK exists yet.

## Wording for the privacy policy and store listing (phase 9)

The export sets `allowBackup` to false, so there is no cloud or adb backup of saves. Android's documentation says some manufacturers' devices can still move app files in a device to device transfer on API 31 and higher. So write that the app never sends saves anywhere. Do not write that saves can never leave the phone.

## Store material (phase 9)

Everything for the Play listing is in `docs/store/`. Nothing has been entered in Play Console. The listing and the privacy policy are drafts for Bart to review.

| File | What it is |
|---|---|
| docs/store/listing.md | Every field to paste into Play Console, with limits and counts |
| docs/store/privacy-policy.md | The privacy policy |
| docs/store/graphics/ | The icon (512 x 512), feature graphic (1024 x 500) and five phone screenshots (1080 x 2160) |

### Make the graphics

Both tools need a rendering display, so run them without `--headless`, from the repo root. Each opens a window for a short time.

```bash
godot --path . --script res://tools/store/make_graphics.gd       # icon and feature graphic, a few seconds
godot --path . --script res://tools/store/make_screenshots.gd    # five real screens, about a minute
```

`make_graphics.gd` draws the icon with `IconArt` and the feature graphic with `Wordmark`, `MapArt`, `Silhouettes` and the palette. `make_screenshots.gd` runs the real app in a SubViewport at 1080 x 2160 with the bundled data, a throwaway save folder (`user://store_shots/`, removed afterwards) and the sound off. It plays three waves of The Fork out of sight and tops up the gold, so the pictures show a full defense. Add `-- --only=wave` (or `front_door`, `modes`, `levels`, `build`) for one picture. Rerun after any change to the look, then run the check.

### Check the store material

```bash
bash tools/store/check_store.sh
```

It checks the character counts in listing.md (the stated count must match the real one, and stay under Google's limit), plain ASCII only (no em dashes or curly quotes), no double hyphens in prose, the required wording in the listing and the policy, and the size of every PNG. Exit 0 means it all passed. When you change a text field, change its `Characters: N of L.` line to match.

### Screenshots from the Fold5

The tool's pictures are enough for the phone slots. If Play Console asks for large screen screenshots, take them on the Fold5's inner screen:

1. Install the build (`bash scripts/install.sh`), unfold the phone, and open Forkline.
2. Capture these four screens with the phone's own screenshot (power and volume down): the front door, the campaign list, a level in its build phase with a gate placed, and a wave in progress.
3. Copy them off with `adb pull` and put them in docs/store/graphics/. Play wants JPEG or 24 bit PNG, each side from 320 to 3840 px, and no side more than twice the other.

### What is still missing for a Play submission

See the end of the phase 9 report. In short: a release key and a signed upload, a bundle (AAB) export, the privacy policy on a public address, Play Console itself, and a few decisions of Bart's. All of these are ask first.
