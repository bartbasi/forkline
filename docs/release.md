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
