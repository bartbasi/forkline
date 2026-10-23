# Forkline: standing rules

Forkline is an original tower defense game for Android phones, built in Godot 4.7.2: hand-built maps whose roads fork, plus gates the player places to steer enemies. Bart Basi owns the project. The main Claude Code session is the Development Manager (DM): it plans, launches every agent, integrates, commits, and is the only one who talks to Bart. Company rules come from C:\bart\playbook\PLAYINC_PLAYBOOK.md (version 1); the decisions that apply are copied below so this file stands on its own. The full kickoff brief is in docs/BRIEF.md. Read it before starting any phase.

## Fixed decisions (ask Bart before revisiting any of these)

- Engine: Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`), the standard build, not .NET. Compatibility renderer (2D).
- Language: GDScript, statically typed everywhere (typed variables, parameters and return values). No C#, no GDExtension, no addons. project.godot treats untyped declarations as errors.
- Platform for v1: Android first. Develop and iterate in the Godot editor on Windows. iOS, Windows and Linux builds are out of scope.
- Orientation: portrait by default. On a foldable's inner screen, or any window close to square or wider than tall, the game switches to a landscape layout on its own, with no setting. Layout follows window size, not an orientation lock. The approach is written in docs/ARCHITECTURE.md before UI work starts.
- Name: Forkline. Store title "Forkline: Tower Defense". Folder C:\bart\forkline. Repo github.com/bartbasi/forkline, public by default once Bart approves the first push. Android package `io.github.bartbasi.forkline`, which can never change once the app is on Play.
- Copyright line, exactly: `Copyright 2026 Play, Inc.` In NOTICE, README, About and anywhere else a copyright line shows. About also says "Made by Bart Basi". NOTICE and the attribution term say "Designed and written by Bart Basi, with assistance from Claude."
- License: GNU GPL version 3 with the three section 7 terms in NOTICE (playbook template 16.1). LICENSE is the official gnu.org text, byte for byte (MD5 `1ebbd3e34237af26da5dc08a4e440464`). Never edit it. UI copy never counts the terms: say "with additional terms".
- Source file header on every source file, checked by a test:
  `# Forkline. Copyright 2026 Play, Inc.`
  `# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.`
- Network: none. No network code anywhere. Release builds request no Android permissions, not even INTERNET. No ads, analytics, tracking, accounts, leaderboards, purchases or real money. Everything is earned by playing.
- The only exits from the app hand a fixed constant address to another app on the phone: Buy me a coffee (`https://buymeacoffee.com/playinc`, browser), the source code link in About (browser), and Send feedback in About (email app, to bartbasi@gmail.com). The app itself sends nothing. Tests replace the opener so nothing real opens.
- Assets: every visual, effect, sound and piece of music is made in code. No image, audio or asset store files. Generated outputs (launcher icons, store graphics) are drawn by tool scripts and committed. Approved third party files: the GPL text, and the Outfit font with its OFL.txt only if Bart picks it at hard stop A. Anything else: ask first. Every asset is logged in docs/ASSETS.md.
- No other game's name appears anywhere players can see: UI, listing, marketing. The look copies no existing game's characters, layouts, palettes or tower designs.
- Content stays non-gory so the rating stays Everyone. Store target audience 13 and over.
- Models: Claude Opus 5.5 (`claude-opus-5-5`) and Claude Sonnet 5.5 (`claude-sonnet-5-5`) only. Effort levels high and max only. Each agent's model and effort are set in its file in .claude/agents/.
- Out of scope: networking of any kind, cloud saves, iOS, Windows and Linux builds, player-made skins or any file import, a look picker, release signing and Play Console work (ask first), and anything not in docs/BRIEF.md.

## Ownership

Each agent edits only what it owns, plus any path its task brief from the DM explicitly grants for that task. Godot's `.uid` and `.import` files belong to whoever owns the file next to them. A path not in this table belongs to the DM until the DM assigns it in a task brief and records it here.

| Path | Owner |
|---|---|
| CLAUDE.md, docs/BRIEF.md, docs/ASSETS.md, .claude/agents/, project.godot, scenes/main.tscn, LICENSE, NOTICE, README.md, .gitignore, .gitattributes, docs/.gdignore, tests/run_tests.gd, tests/base_test.gd, tests/project/, git | DM |
| docs/design/, data/stats/ | game-designer |
| docs/ARCHITECTURE.md | architect |
| docs/art/, src/theme/, prototypes/theme/, tools/icon/, icons/, tests/theme/ | art-director |
| src/sim/, tests/sim/, src/save/, tests/save/ | sim-engineer |
| data/levels/, data/segments/, tests/levels/ | level-designer |
| tools/balance/, docs/balance/ | balance-analyst |
| src/run/, data/cards/, data/runs/, tests/run/ | roguelite-engineer |
| src/ui/ (including the app glue in src/ui/app.gd), scenes/ui/, tests/ui/ | ui-engineer |
| src/render/, shaders/, tests/render/ | render-engineer |
| src/audio/, tests/audio/ | audio-engineer |
| scripts/, export_presets.cfg, tools/store/, docs/store/, docs/release.md | release-engineer |
| docs/reviews/qa-*.md | qa-reviewer |
| docs/reviews/security-*.md | security-reviewer |

Autoload and input map entries in project.godot are added by the DM during integration, so two agents never edit that file at once. The contract plans no autoloads. scenes/main.tscn only instances scenes/ui/app.tscn.

## Decisions from Bart

- 2026-10-23: Path design is hybrid: hand-built maps with forks, plus gates the player places to close branches.
- 2026-10-23: Version 1 includes the campaign with stars, Twist versions, the roguelite mode and the daily challenge. No networking of any kind.
- 2026-10-23: Portrait by default, landscape automatically on foldable inner screens.
- 2026-10-23: Theme is cozy storybook fantasy: a warm hillside village at dusk, towers as lantern-lit watch posts and cottages, enemies as mischievous night creatures that puff into sparkles, no blood (brief section 4).
- 2026-10-23: Name Forkline. Store title "Forkline: Tower Defense". Package name `io.github.bartbasi.forkline`.
- 2026-10-23: "Play" on the front door opens a mode screen with Campaign, Roguelite and Daily. When a level or run is saved, a Continue card sits at the top of that screen and resumes it in one tap. This replaces the playbook's "Play continues the saved session" default.
- 2026-10-23: Optional Relaxed difficulty next to Normal (the default), picked per level or per run. Relaxed gives more lives and more starting gold and changes nothing else. A Relaxed win earns one star; the second and third stars need Normal. The daily challenge is always Normal.
- 2026-10-23: About has a tappable source code link and a Send feedback button (playbook 6.3). Pause has a quiet Buy me a coffee row. The coffee button is also at the bottom of the front door and in About's "Supporting Forkline" section (playbook defaults). It is not on the play screen. The privacy policy names all three outbound buttons.
- 2026-10-23: Models are Claude Opus 5.5 and Claude Sonnet 5.5 only, at effort high or max only, as in the brief's section 7.1 table.
- 2026-10-23: Everything else follows the playbook defaults: Godot 4.7.2, GDScript statically typed, Android first, assets made in code, GPL v3 with the Play, Inc. terms.
- 2026-10-23: Paths the brief gives no owner (the main scene and app glue, save file reading and writing for progress and settings, docs/ASSETS.md, the launcher icon tool, tower and enemy stat data) stay with the DM until the architect names an owner in the contract. The DM then records them in the ownership table.
- 2026-10-23: Owners for the open paths, from the architect's proposal: data/stats/ to the game designer; data/runs/ to the roguelite engineer; tools/icon/, icons/ and tests/theme/ to the art director; tests/render/ and tests/audio/ to those areas; the app glue to the ui-engineer. One change by the DM: src/save/ and tests/save/ go to the sim engineer (Opus), not the roguelite engineer, because saves are the most security sensitive code and the sim engineer already owns sim state saving. docs/ASSETS.md stays with the DM.
- 2026-10-23: The architect gets WebSearch and WebFetch, for research only (Android large-screen behavior). The game itself has no network code.
- 2026-10-23: Bart approved the kickoff and told the DM to go ahead with what it thinks best. Where the brief is silent, follow the playbook.
- Open until hard stop A: the font (Outfit, the system font, or both depending on where it shows).
- Open until the architect proposes it: whether resuming after the app is killed returns to the exact moment or to the start of the current wave (brief 3.10). Bart decides.
- Open until the game designer proposes it: a limited mid-wave gate switch for later levels (brief 3.4). Bart decides.

## Rules for every session and agent

- Read docs/BRIEF.md, CLAUDE.md and docs/ARCHITECTURE.md (once it exists) before starting any task.
- docs/ARCHITECTURE.md is the contract. Build against it. Contract changes and changes to anyone else's area go through the DM. Never edit another area's files.
- Agents never commit or push. The DM commits after each integration step, once all tests pass, with a plain message saying what changed and why. Commits are authored as the bartbasi account, set in this repo's git config only.
- Keep it simple. No features, settings or abstractions beyond the brief. Ideas go in reports as suggestions for Bart.
- Priority for every decision and fix: security and bugs first, then fun and polish.
- No em dashes and no double hyphens in prose: docs, UI text, code comments, commit messages. Short, plain sentences. No marketing voice. Command line flags inside code formatting are fine.
- If anything is unclear, conflicts, or would force a guess, stop and ask. Do not pick an interpretation silently.
- The game rules run in plain classes with no UI or Node dependencies, on a fixed timestep with seeded randomness, so the same inputs always give the same result.
- Saves: JSON only, read through the JSON parser. Never `str_to_var`, `bytes_to_var`, `FileAccess.get_var`, `ConfigFile`, `load()` or any loader that can create objects from file data. Validate every loaded field (type, range, shape) and fall back safely to defaults. Write atomically (temp file, then rename) and handle a failed rename. Put a far ceiling on loaded numbers to refuse tampered saves, never a limit a real player can reach.
- Every outbound address is a constant, written once, never built from input.
- Color is never the only signal. Text meets 4.5:1 contrast, checked by a script. Touch targets at least 48 dp. Respect safe areas. 60 fps on the Fold5.
- The DM runs at most four agents at once and works phase by phase. Never launch the whole team together. If a max effort agent stalls, sprawls or adds unrequested features, the DM drops it to high for that task and tells Bart.
- Hard stops: A, Bart approves the rules and the look and picks the font. B, Bart playtests region 1 on his phone before more content. C, ask before creating the GitHub repo and the first push. Ask first before GitHub Pages, any signing, any Play Console work, and anything outside the brief. Play Console waits for Play, Inc.'s DUNS number.
- Before the first push, remind Bart to search "Forkline" in Google Play on his phone and run a quick trademark search.
- End every phase with a short status for Bart: done, verified, next, blocking.
- Every agent ends with a short report: files changed, how it was proven (command and result, test names, screenshot path), open questions, contract change requests.

## Commands

Run Godot commands from the repo root in the Bash tool.

```bash
godot --headless --path . --import                            # build the class cache (fresh clone, or after adding a class_name)
godot --headless --path . --quit                              # project opens and runs
godot --headless --path . --script res://tests/run_tests.gd   # all tests; exit code 0 means every test passed
```

## Writing tests

- Put tests in `tests/<area>/test_*.gd`. Each file starts with `extends "res://tests/base_test.gd"`.
- Every method named `test_*` runs on a fresh instance. Tests are synchronous.
- Seed every random generator so results repeat.
- Optional hooks: `before_each()`, `after_each()`.
- Helpers: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_null`, `assert_not_null`, `assert_near`, `fail`.
- A script error raised while a test runs (a null access, for example) counts as a failure.
- `-- --only=sim,run` after the test command runs only those folders under tests/.
- tests/project/ checks the source file header on every .gd and .gdshader file, the LICENSE MD5 and the NOTICE credit lines.

## Environment notes (this Windows machine)

- `godot` on PATH is a WinGet link to the Godot 4.7.2 exe. Use it from Bash, where it returns real exit codes. In PowerShell it does not wait or return an exit code unless its output is piped.
- Do not use `godot_console.exe`. It fails with "CreateProcess failed, error 193" because of a stray installer log file directly in `C:\Users`. Bart wants that file left alone: never move, rename or delete it.
- Other projects run Godot on this machine at the same time. Never end Godot processes by name (`taskkill /IM`, `pkill godot`, `Stop-Process -Name`). End only a process you started, by its PID, and wrap long Godot runs in `timeout`.
- Paths in committed files: never write the Windows account name. Use `%TEMP%`, `%APPDATA%` or `%USERPROFILE%` style placeholders.
- Android SDK at `C:\Android\Sdk`. adb is at `C:\Android\Sdk\platform-tools\adb.exe`, not on PATH. JDK 17 (Temurin) is on PATH. Export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable`. The debug keystore lives in `%APPDATA%\Godot\keystores\`, outside the repo.
- Pushing (DM only, after hard stop C): git's credential manager has no GitHub login here, so push through gh: `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push origin main`.
