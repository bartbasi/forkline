# Forkline: Architecture

Owner: architect. Status: revised for phase 7, and brought up to the built sim (S1), the run code (R1, R2), the saves (S2), the run segments (L4), the Twist and run screens (U2), the rules alignment (G1), the run tuning (G3), the security fixes (S4, R4, S5) and the ceilings on stacked effects (S6, S7), 2026-10-25.

This is the contract every agent builds against: folders and owners, ids and data files, every public class with its methods and data shapes, routing, saves, resume, orientation, outbound links, the performance budget, the tests and the build plans for phase 5 (section 11) and phase 7 (section 13). Do not invent a public method that another area must call. If you need a change here, put it in your report for the DM.

Sources: docs/BRIEF.md, CLAUDE.md (with Bart's hard stop A decisions), docs/design/RULES.md and docs/art/NAMES.md. RULES.md holds every game rule and number, and it wins over this document on every rule. If the two disagree, this document has a bug: report it. "RULES 7.3" means section 7.3 of RULES.md.

Parts marked (phase 7) belong to the roguelite mode, the daily challenge or Twists. They are built in phase 7, in the order of section 13.

## 0. Principles

1. **The rules are pure.** src/sim/ and src/run/ extend RefCounted only. No Node, no scene tree, no Input, no files, no real time and no floats in game state. The same inputs give the same result on every phone and on Windows.
2. **The sim resolves, the view follows.** Render and UI read sim state every frame and send player commands as method calls. They never write sim state.
3. **Data holds the numbers.** Towers, creatures, rules, levels, segments, wave packs, cards and the run plan are JSON files under data/, checked field by field on load.
4. **Ids are stable, names are text.** Code, tests and saves use ids. Every name a player reads lives in a data file (2.1), so a rename changes text only.
5. **One composition root, no autoloads.** The App creates every service once and passes it down with `setup()` calls. project.godot gets no autoload and no input map entries.
6. **Files in one place.** In the game, only src/save/ opens data and save files, and everything it reads goes through the JSON parser and a field by field check. About also reads LICENSE, NOTICE and src/theme/fonts/OFL.txt as plain text. Scenes and the font come in with `preload`. Nothing calls `load()`.
7. **Statically typed GDScript.** Every variable, parameter and return value has a type. After adding or renaming a `class_name`, run `godot --headless --path . --import`.

## 1. Folders and owners

The ownership table in CLAUDE.md is the source. This is the same layout, with what each folder holds.

```
forkline/
  project.godot, LICENSE, NOTICE, README.md, CLAUDE.md    DM
  scenes/main.tscn                                        DM: only an instance of scenes/ui/app.tscn
  scenes/ui/, src/ui/                                     ui-engineer: every screen, the HUD, input, layout, the App glue in src/ui/app.gd
  src/sim/                                                sim-engineer: the rules engine
  src/save/                                               sim-engineer: data loading and every save file
  src/run/                                                roguelite-engineer: runs, drafts, the daily (phase 7)
  src/render/, shaders/                                   render-engineer
  src/audio/                                              audio-engineer
  src/theme/                                              art-director: tokens, silhouettes, map art, UI theme, wordmark, icon art
  src/theme/fonts/                                        art-director: Outfit[wght].ttf and OFL.txt, unmodified
  data/stats/                                             game-designer: towers.json, enemies.json, rules.json
  data/levels/                                            level-designer: campaign.json and one file per level
  data/segments/                                          level-designer: run map segments and wave packs (phase 7)
  data/cards/, data/runs/                                 roguelite-engineer (phase 7)
  icons/, tools/icon/                                     art-director: launcher icon PNGs and the tool that draws them
  tools/balance/, docs/balance/                           balance-analyst
  tools/store/, scripts/, export_presets.cfg              release-engineer
  tests/<area>/                                           that area's owner (section 10); tests/project/ is the DM's
  prototypes/theme/                                       art-director: the slice, deleted once its parts are in src/theme/
  docs/                                                   as in CLAUDE.md; docs/ASSETS.md stays with the DM
```

### 1.1 Who may use what

- src/sim/ and src/theme/ use nothing outside Godot's core types.
- src/run/ uses src/sim/.
- src/save/ uses src/sim/ and src/run/.
- src/render/ uses src/sim/ (read only) and src/theme/.
- src/audio/ uses only the event names of src/sim/.
- src/ui/ uses everything.
- tools/balance/ uses src/save/, src/run/ and src/sim/. tools/icon/ and tools/store/ use src/theme/.
- Nothing lower uses anything higher, so there are no cycles. tools/ code uses preload and adds no class names.

## 2. Ids, data model and data files

### 2.1 Units, ids and text

- **Time** in data: milliseconds, a multiple of 50 (one tick). Every RULES.md time is a multiple of 0.1 s, so it fits.
- **Distance, range, reach and radius** in data: hundredths of a tile. 250 is two and a half tiles.
- **Speed** in data: hundredths of a tile per second. 100 is one tile a second.
- **Percent and strength**: whole numbers. 30 means 30 percent.
- **Gold, health, damage, armor, lives, counts**: whole numbers.
- Every number is a JSON number with no fraction part. Godot's JSON parser returns every number as a float, so a check accepts 2 and 2.0 and refuses 1.5, NaN, infinity and anything out of range.
- **Ids**: 1 to 32 characters of `a` to `z`, `0` to `9` and `_`, starting with a letter. Unique within their kind. StringName in code. Players never see an id. An id never changes once it is in a data file, because saves store ids.
- **Display text** (names, plurals, info lines, hints, Twist and card text): printable ASCII, no tabs or line breaks. Names at most 24 characters, other text at most 80. Every data and save file is plain ASCII. Data text always shows in a Label, never as BBCode.
- **Where display text lives.** Only in these data fields:
  - towers and tier 3 paths: data/stats/towers.json `name`, `plural`, `info`;
  - creatures and bosses: data/stats/enemies.json `name`, `info`;
  - regions: data/levels/campaign.json `name`;
  - levels: data/levels/<id>.json `name`, `hint.text`, `twist.name`, `twist.text`;
  - cards (phase 7): data/cards/cards.json `name`, `text`.

  Fixed UI text in src/ui/ (buttons, messages, the star rule sentences in 2.7) never names a tower, path, creature, boss, region, level or card. It takes those names from the data. Level numbers such as 1-3 come from the campaign order, and entrance letters A to D from entrance numbers 1 to 4. Tests compare ids, never names. A rename changes those data fields and RULES.md, and nothing else.
- **Cells** in JSON are `[column, row]`. Column 0 is the left, row 0 the top. In code a cell is a Vector2i(column, row).

### 2.2 Ids

These ids are fixed. They come from docs/art/NAMES.md, and src/theme/ already uses them. NAMES.md proposes the display names. The agreed names go into the data fields above. An id stays the same even when its name changes, so `prize_pumpkin`, `giant_bow` and `star_bloom` stay whatever their final names are.

| Kind | Ids |
|---|---|
| Towers (RULES 5) | `sling_post`, `pumpkin_catapult`, `lullaby_bell`, `longbow_loft`, `firework_tower`, `bakery` |
| Tier 3 paths, spec 0 then spec 1 | `sling_post`: `quickshot`, `stone_sling`. `pumpkin_catapult`: `prize_pumpkin`, `jam_pot`. `lullaby_bell`: `hush_bell`, `night_bell`. `longbow_loft`: `giant_bow`, `triple_bow`. `firework_tower`: `star_bloom`, `skyrocket`. `bakery`: `grand_oven`, `spice_kitchen` |
| Creatures (RULES 6.1) | `scamp`, `pip`, `skitter`, `flitter`, `shellback`, `bubbler`, `puffball`, `puff`, `mender`, `gatecrasher`, `dusk_moth` |
| Bosses (RULES 6.3) | `grumblesack`, `ironshell`, `moon_moth`, `old_tusk` |
| Regions (RULES 12.1) | `lantern_hill`, `millbrook`, `willow_fen`, `moonspire_keep` |
| Levels (RULES 12.3) | `r1_l1` to `r1_l6`, `r2_l1` to `r2_l6`, `r3_l1` to `r3_l6`, `r4_l1` to `r4_l6`. Level 2-3 is `r2_l3`. |
| Cards (phase 7) | The RULES.md card name in id form, for example `spare_gate`, `crowded_night`. Tower cards have no RULES name: `tower_` plus the tower id, for example `tower_bakery`. The full list is in 2.11. |
| Run plan and segments (phase 7) | Segment ids are the level designer's, in the same id form, one per file. The assembled run map has the level id `run`. |

One style for every kind: the NAMES.md name in id form, so a region is `lantern_hill`, never `region_1`. Levels are the one exception: `r1_l1` style ids give a level's place in the campaign, because level names are display text that may still change.

Spec order is the order of the RULES.md tier tables: spec 0 is the first tier 3 row. towers.json, `Silhouettes` and saves use the same order.

### 2.3 The map grid

Every map is a grid of 7 columns and 8 to 13 rows (Bart, hard stop A; RULES 3.1). Rows are strings of 7 characters:

| Char | Cell | Rules |
|---|---|---|
| `.` | scenery | Nothing happens here. |
| `#` | road | |
| `G` | road with a gate socket | |
| `o` | build spot | One tower per spot. |
| `1` to `4` | entrance 1 to 4 | A road cell on the map edge. Numbered from 1 with no gaps. Players see A to D. |
| `B` | base | A road cell. Exactly one per map. |

Checked on load:

- Road cells are `#`, `G`, `1` to `4` and `B`. Orthogonal neighbors that are both road cells are joined. Diagonal neighbors never are.
- No 2 x 2 block of road cells, so roads are one tile wide (RULES 3.3).
- 1 to 4 entrances. At most 24 build spots and 8 sockets.
- With no gates placed, every entrance reaches the base. With only a Twist's fixed gates closed, every entrance still reaches it.

The sim moves walkers along the cell centers. The render draws roads as smooth bands through those centers with round turns (`MapArt`, 3.9), and may draw walkers on the same curves.

### 2.4 Level files: data/levels/<id>.json (level-designer)

```json
{
  "format": 1,
  "id": "r1_l2",
  "name": "The Fork",
  "grid": [
    "...1...",
    "o..#..o",
    ".#####.",
    ".G.o.#.",
    ".#...#.",
    ".#.o.G.",
    ".#...#.",
    ".#.o.#.",
    ".#####.",
    "..oBo.."
  ],
  "start_gold": 250,
  "gates": 1,
  "strength": 100,
  "towers": ["sling_post", "pumpkin_catapult"],
  "star3": {"kind": "towers_at_most", "value": 4},
  "hint": {"text": "Drop the gate on a road. The line shows their new way.", "cell": [1, 3]},
  "waves": [
    {"groups": [{"enemy": "scamp", "count": 6, "entrance": 1, "at_ms": 0, "every_ms": 1000}]},
    {"strength": 110, "groups": [{"enemy": "scamp", "count": 8, "entrance": 1, "at_ms": 0, "every_ms": 800}]}
  ],
  "twist": {"name": "Stuck Gate", "text": "The gate is stuck on its socket.",
            "effects": [{"type": "fixed_gates", "cells": [[5, 5]]}]}
}
```

The map and waves are placeholders. Both branches are 13 steps long, so with no gate placed the tie break (4.3) sends walkers west, down the left road.

| Field | Type | Limits | Notes |
|---|---|---|---|
| format | int | 1 | |
| id | id | equals the file name | 2.2. GameData checks this, because `LevelData.check` never sees the file name. |
| name | text | 1 to 24 characters | |
| grid | array of strings | 8 to 13 rows of 7 characters | 2.3. On a 13 row map the last row is all `.` (the dock rule below). |
| start_gold | int | 0 to 100,000 | Normal. Twists and Relaxed change it in `Battle.create` (3.1). |
| gates | int | 0 to 3, and at most the socket count | RULES 7.1 |
| strength | int | 50 to 1,000 | Every wave's strength unless the wave sets its own. RULES 6.4 |
| towers | array of tower ids | 1 to 6, no repeats | The towers this level offers. RULES 12.2 |
| star3 | object | 2.7 | Star 3. Stars 1 and 2 are the same on every level. |
| hint | object, optional | `text` 1 to 80 characters, plus at most one of `cell` (inside the map) or `button` (`"call"`, the next wave button) | RULES 9.6, 12.4 |
| waves | array | 1 to 40 waves | |
| waves[].strength | int, optional | 50 to 1,000 | |
| waves[].groups | array | 1 to 8 groups | In spawn order |
| group.enemy | creature id | in enemies.json | |
| group.count | int | 1 to 200 | |
| group.entrance | int | 1 to the number of entrances | |
| group.at_ms | int | 0 to 600,000, multiple of 50 | First spawn, after the wave starts |
| group.every_ms | int | 50 to 60,000, multiple of 50 | Gap between two spawns of this group |
| twist | object, optional | `name` 1 to 24 characters, `text` 1 to 80, `effects` 1 or 2 Twist effects (2.8) | RULES 13 (phase 7) |

Spawn bound: one wave, with its Twist applied, spawns at most 120 creatures, counting `split_count` for each splitter (RULES 12.5). Boss releases depend on play, so the bots measure them (9.1).

Saved levels: `Battle.from_data` also bounds what a saved level's waves can bring. The creatures that summon and the creatures that heal that can be on the map at once stay within `MAX_SUMMONERS` (8) and `MAX_HEALERS` (40) (5.6). Real levels stay far below: their two largest waves hold at most 2 summoners and 12 healers. A saved level is still matched to the bundled one only by its id.

Map height and the dock (7.4, settled 2026-10-24): waves need no shape limit for the portrait dock. A build phase whose open wave preview would cover the map starts with the preview folded into its one line strip. On the Fold5 cover that strip still covers part of the bottom row of a 13 row map, so **the bottom row of a 13 row map is scenery only**: no road, spot, socket, entrance or home. tests/levels checks it for every level file, and for run maps through their bottom segments (2.9). Maps of 8 to 12 rows have no such rule. This is a level design rule, not a load check, so `LevelData.check` does not change.

### 2.5 Campaign order: data/levels/campaign.json (level-designer)

```json
{"format": 1, "regions": [
  {"id": "lantern_hill", "name": "Lantern Hill", "levels": ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6"]}
]}
```

Regions and levels in play order. Every listed level exists, and every level file is listed exactly once. The last level of a region is its boss level. The unlock rules are RULES 16, with the star counts in rules.json.

### 2.6 Stats: data/stats/ (game-designer)

Every number comes from RULES 4 to 6. Unknown keys are errors (they catch typos). A missing optional field is 0, false or empty, except `targets`, which is 1. The limits in the tables below are what `Catalog.check` enforces. They are sanity bounds far from any real number, so a typo fails the load instead of breaking a battle. Every time is a multiple of 50 ms.

`towers.json`:

```json
{"format": 1, "towers": [
  {"id": "sling_post", "name": "Sling Post", "plural": "Sling Posts",
   "info": "Quick pebbles at one target. Hits flyers too. Armor blunts it.",
   "kind": "attack",
   "tiers": [
     {"cost": 100, "reach": 250, "hits": "both", "damage": 6, "reload_ms": 500},
     {"cost": 110, "reach": 300, "hits": "both", "damage": 8, "reload_ms": 400}
   ],
   "specs": [
     {"id": "quickshot", "name": "Quickshot", "info": "Fires twice as fast.",
      "cost": 200, "reach": 300, "hits": "both", "damage": 8, "reload_ms": 200},
     {"id": "stone_sling", "name": "Stone Sling", "info": "Big stones that get through armor.",
      "cost": 200, "reach": 300, "hits": "both", "damage": 20, "reload_ms": 500}
   ]}
]}
```

- towers.json holds 1 to 32 towers. A tower has `id`, `name`, `plural` (for the star line "Build no ..."), `info`, `kind` (`attack`, `slow` for the Bell, `boost` for the Bakery), `tiers` (exactly 2: the build, then the tier 2 upgrade) and `specs` (exactly 2 tier 3 paths, spec 0 first, each with `id`, `name` and `info` plus a stat block). `cost` is the price of that step. Path ids are unique across all towers.
- Stat block fields. A field is required for the kinds listed unless it says optional. A field outside its kinds is an unknown key.

| Field | Kinds | Limits | Meaning | RULES |
|---|---|---|---|---|
| cost | all | 10 to 100,000, a multiple of 10 | Price | 4.6 |
| reach | all | 1 to 1,000 | Range, Bell ring or Bakery reach | 5.2, 5.5, 5.8 |
| hits | attack, slow | `ground`, `air` or `both` | What it hits, or what a Bell slows | 5.1, 6.5 |
| damage | attack | 1 to 100,000 | Per hit | 5.2 |
| reload_ms | attack | 50 to 60,000 | The reload time | 5.2 |
| splash | attack, optional | 0 to 500 | Splash radius, 0 for one target | 8.4 |
| targets | attack, optional | 1 to 3 | Creatures per shot | 8.2 |
| pierce | attack, optional | true or false | true: ignores armor | 8.3 |
| slow_pct, slow_ms | slow; attack, optional | 1 to 90, and 50 to 60,000. Both or neither. | The slow given, with this much time left: a Bell gives it every tick, a Jam Pot to each walker it damages | 8.5 |
| boost_pct | boost | 0 to 500 | Attack rate added to attacking towers in reach | 8.6 |
| boost_damage | boost, optional | 0 to 1,000 | Damage added to attacking towers in reach | 8.6 |

`enemies.json` holds 1 to 64 creatures and bosses:

```json
{"format": 1, "enemies": [
  {"id": "scamp", "name": "Scamp", "info": "A small night creature. Each one that gets through costs a life.",
   "health": 40, "armor": 0, "speed": 100, "lives": 1, "bounty": 5},
  {"id": "grumblesack", "name": "Grumblesack", "info": "Huge and slow. Drops 2 Scamps every 6 seconds.",
   "health": 2000, "armor": 0, "speed": 40, "lives": 20, "bounty": 100, "boss": true,
   "summon": {"enemy": "scamp", "count": 2, "every_ms": 6000, "gap_ms": 300}}
]}
```

| Field | Limits | Meaning | RULES |
|---|---|---|---|
| id, name, info | | | 6.6 |
| health, armor, speed, lives, bounty | health 1 to 1,000,000; armor 0 to 1,000; speed 1 to 1,000; lives 1 to 1,000; bounty 1 to 100,000 | Numbers at strength 100 | 6.1, 6.3 |
| flying | | A flyer (4.6) | 6.5 |
| boss | | A boss. It comes only in a final wave. | 6.3 |
| bubble | | Starts with its bubble up. The bubble comes back `bubble_ms` (rules.json) after it pops. | 6.2 |
| heal, heal_reach, heal_ms | 1 to 10,000; 1 to 1,000; 50 to 600,000. All three or none. | Every `heal_ms`, the first time `heal_ms` after it appears, every other creature within `heal_reach` gains `heal` (at strength 100), up to its max health | 6.2 |
| split_into, split_count, split_gap_ms | a creature id; 1 to 10; 50 to 60,000. All three or none. | Released where it is defeated: the first in the spawn step of the next tick, then one every `split_gap_ms` | 6.2 |
| break_ms | 50 to 600,000 | A gate breaker (4.5) | 7.7 |
| summon | `count` 1 to 20, `every_ms` 50 to 600,000, `gap_ms` 50 to 60,000 | `{"enemy", "count", "every_ms", "gap_ms"}`: the first time `every_ms` after it appears, then every `every_ms`, `count` creatures `gap_ms` apart | 6.3 |
| speed_up | `at_pct` 1 to 10 values, each 1 to 99 and lower than the one before; `add` 1 to 1,000 | `{"at_pct": [75, 50, 25], "add": 10}`: the first time health falls to each percent, speed rises by `add` from the next tick | 6.3 |
| release | `at_pct` 1 to 99, `count` 1 to 20, `gap_ms` 50 to 60,000 | `{"at_pct": 50, "enemy", "count", "gap_ms"}`: once, starting on the next tick, even if the same hit defeats it | 6.3 |

Release checks: the creature named by `split_into`, `summon.enemy` or `release.enemy` exists, is not the releaser itself and is not a boss. It has no `split_into`, `summon` or `release` of its own, so releases never chain. A flyer releases only flyers, because a released walker starts on its releaser's road step (RULES 6.2). A summoned creature has no `heal`: summons come for as long as the boss lives, so a save could not bound the healers they bring.

`rules.json`, every key required:

```json
{"format": 1,
 "start_lives": 20, "relaxed_lives_pct": 200, "relaxed_gold_pct": 150,
 "refund_pct": 70, "early_bonus_pct": 50, "clear_bonus": 20, "clear_bonus_per_wave": 5,
 "star2_lives": 15, "max_waves_running": 2, "max_gates": 3, "bubble_ms": 2000,
 "region_stars": [0, 6, 12, 18], "run_stars": 12}
```

| Key | Limits | Rule | RULES |
|---|---|---|---|
| start_lives, relaxed_lives_pct | 1 to 1,000; 100 to 1,000 | Lives in the campaign and runs. Relaxed doubles them. | 4.4, 11 |
| relaxed_gold_pct | 100 to 1,000 | Relaxed starting gold: Normal times 150 / 100, rounded up to a multiple of 10 | 11 |
| refund_pct | 0 to 100 | Refund for every purchase not made in the current build phase, rounded down | 4.6 |
| early_bonus_pct | 0 to 100 | Early call bonus: this percent of the bounty of the newest wave's creatures still on the map, rounded up | 4.9 |
| clear_bonus, clear_bonus_per_wave | 0 to 10,000; 0 to 1,000 | Clear bonus: (20 + 5 x wave number) x strength / 100, rounded half up | 4.5 |
| star2_lives | 1 to `start_lives` | Star 2 | 10.2 |
| max_waves_running | 1 to 10 | Waves on the map at once | 4.9 |
| max_gates | 0 to 8 | Most gates a level or run gives | 7.1, 14.5 |
| bubble_ms | 50 to 60,000 | Time until a bubble comes back | 6.2 |
| region_stars | 1 to 8 values, each 0 to 1,000 and never lower than the one before | Stars each region needs, with the previous region's last level cleared | 16 |
| run_stars | 0 to 1,000 | Stars that open the roguelite and the daily | 16 |

### 2.7 Star rules (RULES 10)

- Star 1: win, on Normal or Relaxed.
- Star 2: win on Normal with at least `star2_lives` lives left. The UI writes "Keep 15 lives."
- Star 3: win on Normal while meeting the level's `star3` challenge.
- A Relaxed win earns star 1 only. Each star is kept for good once earned, and the three can come from different wins. Twists have no stars: a Twist win only marks that Twist cleared.

`star3` kinds. The UI builds each sentence from the kind, the number and the tower's `plural`:

| kind | Field | Sentence | Met when |
|---|---|---|---|
| `no_lives_lost` | none | Lose no lives. | Lives at the win equal the starting lives. |
| `towers_at_most` | `value` | Have at most N towers. | The towers on the map were never more than N. Bells and Bakeries count. |
| `tower_ban` | `tower` | Build no (plural). | That tower was never built. |
| `gates_at_most` | `value`, 0 to 3 | Use at most N gates. At 0: Use no gates. | At the start of every wave, at most N gates were placed. |
| `tier_at_most` | `value`, 1 or 2 | At 1: Upgrade no towers. At 2: No tower above tier 2. (Bart, hard stop B) | No tower went above tier N. |
| `early_calls_at_least` | `value` | Call N waves early. | At least N waves were called early. |
| `kinds_at_most` | `value` | Use at most N kinds of tower. | At most N tower types were built. |
| `gates_whole` | none | Use every gate and keep them whole. | At the start of every wave every gate was placed, and no gate broke. |

`value` is 0 to 100. RULES 10.3 also asks every challenge to leave two kinds of attacking tower usable. tests/levels/ checks that.

**Stars during play** (phase 7, FUN_REVIEW_R1 item 2, approved at hard stop B). Only in a campaign level that is not a Twist; runs, dailies and Twists have no stars.

- The Pause menu (where a resumed game also opens) shows the three star lines. A line says "Earned" when Progress already holds that star for the level, else "Not yet" while `Battle.stars_possible()` (3.1) still has its bit, else "Lost". A lost line is struck through and says "Lost", so it never relies on color. On Relaxed, lines 2 and 3 say "Normal only" unless already earned, and are not struck through (RULES 10.6).
- The UI warns before a tap that would lose star 3, as the Upgrade button already does: in the build panel for a tower where `Battle.loses_star3(&"build", tower)` is true (a tower over the limit, a banned tower, a kind over the limit), on an upgrade where `loses_star3(&"upgrade", &"", tier)` is true, and in the gate message when placing a gate where `loses_star3(&"gate")` is true. A gate loses the star only if a wave starts with it placed, and the message says so. Warnings show only on Normal and only while star 3 is not already earned. These queries replace the UI's own tier check, which misses a tower that went above the cap and was then sold.

### 2.8 Effects: Twists and cards

A Twist or a card is a list of effects. Each effect is an object with a `type` from this closed list and exactly the fields shown. The sim implements each type once.

Uses: **Twist** effects last the whole level. **card** effects last the rest of the run, or change the state once where the table says instant. **risk** effects (the effects of a risk card) wait for the next wave that starts and change only that wave. At most one risk card waits at a time.

Which creatures an effect reaches: a Twist's creature effects reach every creature of every wave, bosses and released creatures (Puffs, boss summons and releases) included. A risk card's creature effects reach every creature of the wave it changes, that wave's released creatures included. `count_pct` changes only the counts of the wave's own groups in the level or pack data. Groups added by `add_group` keep the count their card states, and releases keep their data counts (RULES 13, 14.5).

| type | Fields | Use | What it does | RULES |
|---|---|---|---|---|
| `start_gold_pct` | pct | Twist | Starting gold times pct / 100, rounded down to a multiple of 10 | 13 |
| `set_lives` | lives | Twist | Normal starting lives | 13 |
| `set_gates` | count | Twist | The gates the level gives, 0 to `max_gates` | 13 |
| `fixed_gates` | cells | Twist | Gates start on these sockets. They cannot be moved or removed, and each one comes out of the level's gates. | 13 |
| `ban_tower` | tower | Twist | The tower cannot be built | 13 |
| `tier_cap` | tier (1 or 2) | Twist | No tower can go above this tier | 13 |
| `no_selling` | none | Twist | Towers cannot be sold | 13 |
| `count_pct` | pct, flyers, last_wave | Twist, risk | Group counts times pct / 100, rounded up. Only the wave's own groups; never an `add_group` group. `flyers` true: groups of flyers only. `last_wave` true: the final wave only; a risk card always has false. | 13, 14.5 |
| `health_pct` | pct | risk | Max health times pct / 100, rounded half up, after strength | 14.5, 14.6 |
| `speed_pct` | pct | Twist, risk | Speed times pct / 100 | 13, 14.5 |
| `armor_add` | amount | Twist | Armor plus amount | 13 |
| `all_bubbles` | none | Twist | Every creature starts with a bubble, which comes back as a Bubbler's does | 13 |
| `break_ms` | enemy, ms | Twist | That creature breaks gates in ms. It must already break gates (`break_ms` in enemies.json). | 13 |
| `gates_open` | none | risk | From the start of that wave until the next build phase, gates block nothing and cannot be broken | 14.5 |
| `add_group` | enemy, count, entrance, at_ms, every_ms, after_last | risk | One more group, after the wave's own groups in spawn and preview order, belonging to that wave. `after_last` true: at_ms counts from the largest `at_ms` among the wave's own groups. The entrance must exist on the map: `add_effects` refuses the effects with `&"bad_effect"` otherwise, so cards.json uses entrance 1 (2.11). | 14.5, 14.6 |
| `reward_gold` | amount | risk | Times that wave's strength / 100, rounded half up. Paid with that wave's clear bonus and counted in its `wave_cleared` event's `gold`. `clear_bonus_pct` does not change it. Nothing is paid if the game ends before that wave is cleared. | 14.5 |
| `add_tower` | tower | card | The tower can be built | 14.5 |
| `tower_add` | tower, stat, amount | card | Adds to that stat of every tier and path of the tower. stat: `damage`, `reload_ms`, `reach`, `splash`, `slow_pct`, `targets`, `boost_pct` or `boost_damage` | 14.5, 14.6 |
| `tower_pct` | tower, stat, pct | card | That stat times pct / 100, rounded half up. stat: `damage` or `reload_ms` | 14.5, 14.6 |
| `tower_hits_air` | tower | card | The tower also hits or slows flyers | 14.6 |
| `bounty_pct` | pct | card | Bounties times pct / 100, rounded half up. The early call bonus is worked out from these bounties. | 14.5 |
| `clear_bonus_pct` | pct | card | Clear bonuses times pct / 100, rounded half up | 14.5 |
| `refund_pct` | pct | card | Replaces rules.json `refund_pct`. pct is 1 to 100, so selling never pays a profit. | 14.5 |
| `cost_add` | build, upgrade | card | Added to every build price and every upgrade price, never below 10 | 14.6 |
| `interest` | pct, max | card | When each build phase begins, after the clear bonus, gain pct of the gold held, rounded down, at most max. The `interest` event (3.1) reports the gain. | 14.6 |
| `gates_stay` | none | card | Each time a wave starts, every placed gate becomes fixed (RULES 14.6) | 14.6 |
| `add_gates` | count | card, instant | Gain gates, never more than `max_gates` placed and in hand together | 14.5, 14.6 |
| `add_gold` | amount, per_wave | card, instant | Gain amount plus per_wave for each wave cleared so far | 14.5 |
| `add_lives` | amount | card, instant | Gain lives, never above the battle's starting lives (`start_lives`). A gain never lowers lives. | 4.4, 14.5 |

- Order: a Twist's start effects come before Relaxed (RULES 11). Tower stats: the data, then every `tower_add`, then every `tower_pct`, then Bakery boosts on top (RULES 8.7). Creatures: the data, then strength, then effects, each step rounded by its own rule.
- Floors after card effects: price at least 10, reach at least 1, reload at least 50 ms, damage at least 1 on a tower that deals damage, splash at least 0, targets at least 1, a slow from 1 to 90 percent on a stat block that has a slow (a card never adds a slow to one that has none), boosts at least 0. There are no rule ceilings beyond the slow's 90 percent, so Volley gives a Triple Bow 4 targets. The far ceilings of 5.6 refuse a card rather than clamp it: `add_effects` returns `&"bad_effect"` for a card that would take a tower stat, a gold gain or the next wave past one (3.1).
- Instant effects change the state once and are not kept, so a restore never applies them twice. Every other effect is kept by the battle and saved with it.
- Checks (`Modifiers.check`): the type is known and allowed for its use; the fields are exact; every id exists; pct is 1 to 1,000, except `refund_pct`, which is 1 to 100; counts are 1 to 200, except `set_gates` count, which is 0 to `max_gates` (the No Gates Twist gives 0); `set_lives` is 1 to 1,000; entrances are 1 to 4; times are multiples of 50 up to 600,000; `add_gold` `amount` and `per_wave`, `add_lives` `amount`, `reward_gold` `amount` and `interest` `max` are whole numbers from 0 to 1,000: a negative value is refused when it is loaded or picked, not counted as 0 (2026-10-24); every other number is -1,000 to 1,000; a `break_ms` creature already breaks gates (phase 7). `LevelData.check` also checks that `fixed_gates` cells are sockets of that level, that there are no more of them than the level gives, and that they do not seal. `RunData.check` adds the card rules of 2.11.

The Twists of RULES 13 as effects. The level designer writes them into each level's `twist`, with `name` and `text` from RULES 13:

| Twist | Levels | effects |
|---|---|---|
| Thin Purse | 1-1, 4-1 | `start_gold_pct` 50 |
| Stuck Gate, Stuck Gates | 1-2, 2-6 | `fixed_gates` with one cell (1-2) or two cells (2-6), sockets the level designer picks |
| Tier 2 Cap | 1-3, 3-5 | `tier_cap` 2 |
| No Catapults, No Bells, No Fireworks, No Longbows | 1-4 and 3-2, 2-2, 3-1, 4-2 | `ban_tower` `pumpkin_catapult`, `lullaby_bell`, `firework_tower`, `longbow_loft` |
| Twice the Wings | 1-5, 3-4 | `count_pct` 200, flyers true, last_wave false |
| Double Trouble | 1-6, 3-6, 4-6 | `count_pct` 200, flyers false, last_wave true |
| Hurry | 2-1 | `speed_pct` 120 |
| Thick Shells | 2-3 | `armor_add` 2 |
| No Gates, One Gate | 2-4, 3-3 | `set_gates` 0, `set_gates` 1 |
| Bubble Night | 2-5 | `all_bubbles` |
| Quick Crashers | 4-3 | `break_ms` `gatecrasher` 2000 |
| No Selling | 4-4 | `no_selling` |
| Five Lives | 4-5 | `set_lives` 5 |

Level 1-3's Twist is Tier 2 Cap, with the same name and text as 3-5's: "No tower can go above tier 2." It replaces No Upgrades (DM, 2026-10-24).

### 2.9 Segments and wave packs: data/segments/ (level-designer, phase 7)

A run map is three hand-built segments stacked: top, middle and bottom (RULES 14.2).

```json
{"format": 1, "id": "mid_split", "kind": "middle", "grid": [
  "...#...",
  ".#####.",
  ".G.o.#.",
  ".#####.",
  "...#..."
]}
```

Segments, one file each, data/segments/<id>.json:

- Keys exactly `format` (1), `id` (equals the file name), `kind` and `grid`. `kind` is `top`, `middle` or `bottom`. The grid has the row count run.json sets for its kind (2.10), 7 characters a row, in the characters of 2.3.
- A top segment holds 1 or 2 entrances, `1` then `2`, each on its top row or on column 0 or 6. Middle and bottom segments hold no entrance. A bottom segment holds exactly one `B`; the others hold none.
- **A bottom segment's last row is all `.`** while run.json's `rows` add up to 13, as RULES 14.2 sets them, because a 13 row map keeps its bottom row scenery only (2.4, 7.4).
- No segment holds a 2 x 2 block of road on its own.
- Ports: the columns of the road cells on a top or middle segment's bottom row (its bottom ports), and on a middle or bottom segment's top row (its top ports). On those rows no two road cells are side by side, so a seam never makes a 2 x 2 block. Each of those rows has at least one road cell.
- A segment fits under another when its top ports equal the other's bottom ports, as sets of columns.
- Coverage: there is at least one segment of each kind, every top segment has at least one middle that fits under it, and every middle that fits under some top has at least one bottom that fits under it.
- Valid stacks: every stack of a top, a middle that fits under it and a bottom that fits under that middle, assembled as in 3.4, passes `LevelData.check` and has its spots and sockets within run.json's `spots` and `sockets`. So every pick MapAssembler can make is valid. tests/levels/ checks every stack. `RunData.check` checks everything else in this list at load.
- data/segments/index.json lists every segment file: `{"format": 1, "segments": ["top_twin", "mid_split"]}`, 1 to 256 ids, no repeats. Its order is the order MapAssembler picks from. The game loads only listed files, and tests/levels/ checks that every file in the folder is listed.

The Bakery spot (RULES 14.2): **every stack has a build spot with at least 3 other build spots among its eight neighbors**, so a Bakery there reaches 3 towers. tests/levels/ checks every stack. Like the 13 row rule (2.4), this is a level design rule, not a load check, so `RunData.check` does not change.

Wave packs, data/segments/packs.json (RULES 14.3): `{"format": 1, "packs": [{"id": "band1_scamps", "band": 1, "boss": "", "waves": []}]}`.

- 1 to 256 packs, ids unique. Keys exactly `id`, `band` (1 to 6), `boss` and `waves`. Its order is the order MapAssembler picks from.
- `waves`: exactly 3 waves in the level wave shape of 2.4. A band 6 pack's third wave, its boss wave, has a `strength` (50 to 1,000), required there and allowed on no other pack wave (RULES 14.3). Entrances are 1 or 2; entrance 2 means entrance 1 on a map with one entrance.
- Creatures: a band b pack uses only the creatures that bands 1 to b add (run.json `bands`, 2.10), never a boss except its own, and never `puff` as a group. Band 1 packs' first wave holds only `scamp` (RULES 14.3).
- Bands 1 to 5: `boss` is `""`. Band 6: `boss` is a boss id, and that boss comes only in the pack's third wave, as one group of count 1, with any escort.
- Each band has at least 4 packs, and each boss in enemies.json has at least one band 6 pack.
- Spawn bound: each pack wave spawns at most 120 creatures (2.4, counting `split_count`) with no risk card and with each risk card of cards.json applied in turn. A band 6 pack's third wave, the boss wave, never gets a risk card (3.4), so it is checked without one.
- New creatures (RULES 14.3): for every choice of one pack per band (band 6: every pack), reading waves 1 to 18 in order, a creature the run has not shown yet comes in the wave's first group, no group of that wave starts before it, and no wave brings two such creatures. tests/levels/ checks every choice. The simple way to pass: make every band b pack show every creature that band b adds.
- `RunData.check` checks every rule in this list at load except the new creature rule, which only tests/levels/ checks.

### 2.10 The run plan: data/runs/run.json (roguelite-engineer, phase 7)

```json
{"format": 1, "strength_start": 100, "strength_step": 10,
 "start_gold": 300, "gates": 1, "towers": ["sling_post"],
 "rows": {"top": 4, "middle": 5, "bottom": 4}, "spots": [11, 12], "sockets": [2, 5],
 "bands": [["scamp", "pip"], ["skitter", "flitter", "shellback"], ["bubbler", "puffball"],
           ["mender", "dusk_moth"], ["gatecrasher"], []],
 "weights": {"tower": 30, "perk": 25, "gate": 10, "economy": 20, "risk": 15}}
```

Values from RULES 14.1 to 14.4. Every key is required, and unknown keys are problems. A run always has 6 bands of 3 waves: 18 waves, the 18th a boss wave, and a draft after each of waves 1 to 17 (RULES 14.1, 14.3). That shape is fixed in code (`RunData.BANDS` 6), not data. Lives and the Relaxed numbers come from rules.json, so a Relaxed run starts with 450 gold.

| Key | Limits | Meaning |
|---|---|---|
| strength_start, strength_step | 50 to 1,000; 0 to 100; wave 17's strength at most 1,000 | Waves 1 to 17: wave w has strength `strength_start + strength_step * (w - 1)`. Wave 18 has its band 6 pack's boss wave strength (2.9). |
| start_gold | 0 to 100,000, a multiple of 10 | Normal starting gold |
| gates | 0 to `max_gates` | Gates at the start |
| towers | 1 to 6 tower ids, no repeats | The towers a run starts with |
| rows | exactly `top`, `middle`, `bottom`, each 1 to 11, summing to 8 to 13 | Segment heights (2.9) |
| spots, sockets | `[lo, hi]`: spots 1 <= lo <= hi <= 24; sockets 0 <= lo <= hi <= 8 | What an assembled map must hold (RULES 14.2) |
| bands | exactly 6 lists of creature ids; no boss, no `puff`; each creature in at most one list | The creatures each band adds (RULES 14.3). Band 6 adds none: it uses every earlier one, plus its boss. |
| weights | exactly `tower`, `perk`, `gate`, `economy`, `risk`, each 0 to 1,000; `economy` at least 1 | Draft weights (RULES 14.4). Economy is never 0, and every pool holds an economy card that is not `once` (3.4), so a draft is never empty. |

### 2.11 Cards: data/cards/cards.json (roguelite-engineer, phase 7)

```json
{"format": 1, "cards": [
  {"id": "spare_gate", "kind": "gate", "name": "Spare Gate", "text": "Gain 1 gate, up to 3.",
   "once": false, "unlock": {}, "effects": [{"type": "add_gates", "count": 1}]},
  {"id": "sharp_pebbles", "kind": "perk", "tower": "sling_post", "name": "Sharp Pebbles",
   "text": "Sling Posts deal 1 more damage per hit.", "once": true, "unlock": {},
   "effects": [{"type": "tower_add", "tower": "sling_post", "stat": "damage", "amount": 1}]},
  {"id": "tea_break", "kind": "economy", "name": "Tea Break", "text": "Gain 5 lives, but never more than you started with.",
   "once": false, "unlock": {}, "effects": [{"type": "add_lives", "amount": 5}]},
  {"id": "pip_parade", "kind": "risk", "name": "Pip Parade",
   "text": "Next wave: 16 more Pips. Reward: 120 gold, more in later waves.",
   "once": false, "unlock": {"counter": "stars", "at": 72},
   "effects": [{"type": "add_group", "enemy": "pip", "count": 16, "entrance": 1, "at_ms": 1000, "every_ms": 300, "after_last": false},
               {"type": "reward_gold", "amount": 120}]}
]}
```

- 1 to 256 cards, ids unique. Keys exactly `id`, `kind`, `name` (1 to 24 characters), `text` (1 to 80), `once`, `unlock` and `effects`, plus `tower` for tower and perk cards only. The file's order is the order drafts pick from.
- `kind` is `tower`, `perk`, `gate`, `economy` or `risk`. `once` true: gone for the run after it is taken.
- `unlock` is `{}` for the base cards (RULES 14.5), or exactly `{"counter": name, "at": n}` (RULES 14.6) with n from 1 to 1,000,000. Counter names: the five progress counters (5.5), plus `stars` and `twists_cleared`, worked out from the level records.
- `effects` by kind. A risk card's effects pass `Modifiers.check` for use `risk`; every other card's for use `card`.
  - tower: exactly one `add_tower` of its `tower`. Every tower not in run.json `towers` has exactly one tower card, and no tower in it has one.
  - perk: 1 to 3 effects, each a `tower_add`, `tower_pct` or `tower_hits_air` of its `tower`. The stat must be one the tower's kind has (2.6): `damage`, `reload_ms`, `splash` and `targets` for an attacking tower; `slow_pct` for a Bell, or an attacking tower with a slow on some tier or path; `boost_pct` and `boost_damage` for a Bakery; `reach` for any. `tower_hits_air` for an attacking tower or a Bell.
  - gate: an `add_gates`, and optionally a `gates_stay`.
  - economy: 1 to 3 of `add_gold`, `add_lives`, `bounty_pct`, `clear_bonus_pct`, `refund_pct`, `cost_add` and `interest`.
  - risk: exactly one `reward_gold`, plus 1 to 3 other risk effects. Every `add_group` uses entrance 1 (entrance A, as RULES 14.5 and 14.6 say), which every map has.
- `RunData.check` checks all of this. `RunData.pool(counters)` is the base cards plus every card whose counter has reached its `at`, in file order.

Every card of RULES 14.5 and 14.6 as data. `name` is the RULES name; `text` is the roguelite engineer's, at most 80 characters, from the RULES effect line, and names come from the data as 2.1 says.

| id | kind, tower | once | unlock | effects |
|---|---|---|---|---|
| `tower_pumpkin_catapult`, `tower_lullaby_bell`, `tower_longbow_loft`, `tower_firework_tower`, `tower_bakery` | tower, that tower | true | `{}` | `add_tower` |
| `sharp_pebbles` | perk, `sling_post` | true | `{}` | `tower_add` damage 1 |
| `wide_splash` | perk, `pumpkin_catapult` | true | `{}` | `tower_add` splash 25 |
| `deep_lullaby` | perk, `lullaby_bell` | true | `{}` | `tower_add` slow_pct 10 |
| `steady_aim` | perk, `longbow_loft` | true | `{}` | `tower_pct` reload_ms 80 |
| `bigger_bangs` | perk, `firework_tower` | true | `{}` | `tower_add` damage 5 |
| `warm_ovens` | perk, `bakery` | true | `{}` | `tower_add` reach 100 |
| `spare_gate` | gate | false | `{}` | `add_gates` 1 |
| `gold_purse` | economy | false | `{}` | `add_gold` 100, per_wave 10 |
| `fat_bounties` | economy | true | `{}` | `bounty_pct` 120 |
| `feast_days` | economy | true | `{}` | `clear_bonus_pct` 150 |
| `fair_trade` | economy | true | `{}` | `refund_pct` 90 |
| `tea_break` | economy | false | `{}` | `add_lives` 5 |
| `crowded_night` | risk | false | `{}` | `count_pct` 150 (flyers false, last_wave false); `reward_gold` 100 |
| `thick_hides` | risk | false | `{}` | `health_pct` 150; `reward_gold` 120 |
| `hurry_night` | risk | false | `{}` | `speed_pct` 150; `reward_gold` 60 |
| `gateless_night` | risk | false | `{}` | `gates_open`; `reward_gold` 60 |
| `flock` | risk | false | `{}` | `add_group` flitter, 8, entrance 1, at_ms 2000, every_ms 400, after_last true; `reward_gold` 80 |
| `twin_pebbles` | perk, `sling_post` | true | `best_run_wave` 6 | `tower_add` targets 1; `tower_add` damage -2 |
| `heavy_pumpkins` | perk, `pumpkin_catapult` | true | `best_run_wave` 12 | `tower_add` damage 10; `tower_add` reload_ms 500 |
| `frost_chime` | perk, `lullaby_bell` | true | `dailies_finished` 1 | `tower_hits_air`; `tower_add` reach -25 |
| `volley` | perk, `longbow_loft` | true | `runs_won` 1 | `tower_add` targets 1; `tower_pct` damage 85 |
| `long_fuse` | perk, `firework_tower` | true | `runs_won_normal` 1 | `tower_add` reach 100; `tower_add` reload_ms 250 |
| `spice_rack` | perk, `bakery` | true | `stars` 24 | `tower_add` boost_damage 2; `tower_add` boost_pct -10 |
| `piggy_bank` | economy | true | `stars` 36 | `interest` pct 10, max 50 |
| `bargain` | economy | true | `stars` 48 | `cost_add` build 20, upgrade -20 |
| `iron_gate` | gate | true | `twists_cleared` 1 | `add_gates` 2; `gates_stay` |
| `moonlit_wager` | risk | false | `stars` 60 | `health_pct` 200; `reward_gold` 250 |
| `crasher_escort` | risk | false | `risky_wins` 1 | `add_group` gatecrasher, 2, entrance 1, at_ms 0, every_ms 3000, after_last false; `reward_gold` 150 |
| `pip_parade` | risk | false | `stars` 72 | `add_group` pip, 16, entrance 1, at_ms 1000, every_ms 300, after_last false; `reward_gold` 120 |

That is the 22 base cards and the 12 unlockable ones. Counters (RULES 14.6): a run or daily "reaches" wave N when wave N starts, so `best_run_wave` is the highest wave number started in any run or daily.

### 2.12 How data is checked on load

1. `GameData.load_from()` (src/save/) reads every bundled file through `JsonFile.read()`: a size cap first, ASCII only, then Godot's JSON parser. Never `load()`, `ResourceLoader`, `str_to_var` or anything that can make objects.
2. It hands each parsed value to its owner's check, in this order: `Catalog.check` (stats), the campaign list (GameData itself), `LevelData.check` (each listed level), then `RunData.check` (segments, packs, run plan and cards). The level checks never see file names, so GameData itself checks that each level's `id` equals its file name and that every level file is listed. `RunData.check` gets one Dictionary of parsed files keyed by their path under data/: `"runs/run.json"`, `"cards/cards.json"`, `"segments/index.json"`, `"segments/packs.json"`, and `"segments/<id>.json"` for every id the index lists, in index order. Any other key is a problem. GameData reads the index first and reads only the ids it lists, at most 256 and only in id form, so no path reaches outside data/segments/. A listed file that is missing is left out of the Dictionary, and `RunData.check` reports it. A file that cannot be read (locked, over its cap, not ASCII or not valid JSON) is left out too, and GameData adds its own problem line. A missing data/segments/ folder is a problem like any other missing file. When any run file has a problem, `GameData.run` is null and the problems are in `GameData.problems`. RunData checks that each segment's `id` equals its file name.
3. Each check verifies exact keys, types, whole numbers, ranges, the id format, that every referenced id exists, the map rules in 2.3, times in multiples of 50 ms, the effects in 2.8 and the spawn bound in 2.4.
4. Each check returns every problem as a plain line naming the file and field, for example `r1_l3.json: waves[2].groups[0].count: must be 1 to 200`. An empty list means valid.
5. A bundled file with a problem is a build bug. tests/sim/, tests/levels/ and tests/run/ load every real file and fail on any problem. In the game, if `GameData.problems` is not empty, the App shows one message, "This copy of Forkline is damaged. Installing it again should fix it.", and starts nothing else.

Size caps: a level 64 KB, a segment 16 KB, packs.json 256 KB, each stats file 256 KB, cards.json 256 KB, run.json 16 KB, campaign.json and index.json 16 KB.

## 3. Public classes

Every class below has the listed `class_name`. Fields are read only outside their own area. Signals list typed arguments; emit only those. Methods that refuse bad input return a refusal and change nothing. They never clamp, never crash and never `assert` on player input. `push_error` is for programming errors only. Classes may have more members than listed, but other areas use only the listed ones.

### 3.1 Simulation: src/sim/ (sim-engineer)

#### Timestep and integer math

| Constant | Value | Meaning |
|---|---|---|
| `Sim.TICKS_PER_SECOND` | 20 | One tick is 50 ms of game time. At 3x the sim runs 60 ticks a real second. |
| `Sim.UNIT` | 20000 | Sub-units per tile. A cell center is `cell * UNIT + UNIT / 2`. |

- A data speed of s moves `10 * s` sub-units a tick, and a reach of r is `200 * r` sub-units, so nothing is rounded on load. Data times are whole ticks.
- Game state is int, bool, StringName, Vector2i and arrays of those. No float anywhere in src/sim/. A test scans the folder for `float`, `sqrt(`, `sin(`, `cos(`, `randf`, `randi` and float literals.
- Distances are compared squared. The only root is `Sim.isqrt()`, used once per flyer path.
- A walker moves `speed * 10 * pct * (100 - slow) / 10000` sub-units a tick, where pct is 100 unless `speed_pct` changes it. The one truncation loses under one percent. Movement left over at a cell center carries into the next step, so speeds stay exact over a whole route.
- Rounding follows RULES 2: half up for health, heals, gold scaled by strength or a percent, and damage percents; down for refunds; up for the early call bonus and `count_pct`. Every other product truncates once, at the end.
- Two timers run at a changing pace, so they count in 1/100 ms. A tick takes `50 * (100 + rate boost)` off a tower's reload timer. A tower fires at most once a tick (RULES 5.2): with its timer at 0 or less and a target in range, it fires and adds `reload_ms * 100`, and a timer still below 0 after that is set to 0; with no target, the timer is set to 0 and waits. So between ticks, and in a save, a reload timer is 0 to `reload_ms * 100` of the tower's stats with card effects; an upgrade or a card never leaves it above that. A tick takes `50 * (100 - slow)` off a breaker's break timer (RULES 7.7). Every other timer counts whole ticks.
- No product comes near 2^62: positions stay below 300,000, and the ceilings in 2.4, 5.5 and 5.6 bound every input.

#### No chance in battle

Combat never uses randomness (RULES 8.1). A Battle has no random generator, and a campaign level plays the same every time for the same commands. Runs use seeded generators only to build the run and draw cards (3.4).

#### Order

- Towers act in spot order: row, then column (RULES 3.4). Creatures update in id order, which is spawn order. Any other tie goes to the lower id or the earlier cell. No rule iterates a Dictionary unless its keys were inserted in one of these orders.
- Each tick runs RULES 8.1 in order: 1 spawns (groups in wave data order, waves in start order, then due Puffs and boss releases; each creature gets the next id), 2 timers (bubbles, slows, heals, break timers; a gate whose timer ends breaks now and distances are worked out again), 3 Bells, 4 movement (a creature at the base center is removed and costs its lives; at 0 lives the battle is lost and the tick ends), 5 towers (reload, targets, fire; hits land at once), 6 defeats (bounties, queued Puffs, boss health events for the next tick), 7 wave checks (clear bonus, win, or the next build phase). Then `tick += 1`.
- A released creature (a Puff or a boss release) appears at the spot where its release began. A released walker finishes the step its releaser was on, then takes the shortest open route from there. A release that has begun always finishes, even if its releaser is defeated or gets through (RULES 6.2).

#### Classes

```gdscript
class_name Sim extends RefCounted                      # src/sim/sim.gd: constants and integer helpers
const TICKS_PER_SECOND: int = 20
const MS_PER_TICK: int = 50
const UNIT: int = 20000
const MAP_COLUMNS: int = 7
const MAP_ROWS_MIN: int = 8
const MAP_ROWS_MAX: int = 13
const MAX_ENTRANCES: int = 4
static func isqrt(n: int) -> int                       # floor of the square root; n >= 0
static func center(cell: Vector2i) -> Vector2i         # sub-unit position of a cell center
static func cell_of(pos: Vector2i) -> Vector2i         # the cell holding a sub-unit position
```

```gdscript
class_name DataCheck extends RefCounted                # src/sim/data_check.gd: field checks for parsed JSON (2.12, 5.6)
## Used by src/sim/ and src/save/, and in phase 7 by src/run/. Nobody else. Each reader checks one field. When it is
## wrong, the reader adds the line "<file>: <path>: <why>" to problems and returns a safe fallback, so checking goes on.
## A reader that takes a Dictionary and a key returns its fallback with no problem when the key is missing, because
## object() reports a missing required key.
const LIMIT: int = 1000000000000000                    # a number of 10^15 or more, either way, is refused before it becomes an int
var problems: PackedStringArray
func _init(file_name: String = "") -> void             # the file each problem line names; "" leaves it out
func fail(path: String, why: String) -> void
func ok() -> bool                                      # no problem so far
func object(value: Variant, path: String, required: PackedStringArray, optional: PackedStringArray = PackedStringArray()) -> bool
                                                       # a Dictionary with exactly these keys; true when it is a Dictionary, so reading goes on
func integer(data: Dictionary, key: String, path: String, lo: int, hi: int, step: int = 1, fallback: int = 0) -> int   # whole() on data[key]
func whole(value: Variant, path: String, lo: int, hi: int, step: int = 1, fallback: int = 0) -> int   # a whole number from lo to hi, a multiple of step
func boolean(data: Dictionary, key: String, path: String, fallback: bool = false) -> bool
func ident(data: Dictionary, key: String, path: String) -> StringName   # ident_value() on data[key]
func ident_value(value: Variant, path: String) -> StringName   # an id (2.1); &"" when wrong
func text(data: Dictionary, key: String, path: String, max_len: int) -> String   # display text (2.1); "" when wrong
func array(data: Dictionary, key: String, path: String, lo: int, hi: int) -> Array   # array_value() on data[key]
func array_value(value: Variant, path: String, lo: int, hi: int) -> Array   # an array of lo to hi items; [] when wrong
func pair(value: Variant, path: String, lo: int, hi: int) -> Vector2i   # [x, y], each a whole number from lo to hi; lo - 1 in place of anything wrong
func cell(value: Variant, path: String, rows: int) -> Vector2i   # [column, row] inside the map; (-1, -1) when wrong
static func join(path: String, key: String) -> String  # a key's path: "path.key", or "key" when path is ""
static func is_whole(value: Variant) -> bool           # an int, or a whole, finite JSON number below LIMIT
static func is_string(value: Variant) -> bool          # a String or a StringName
static func is_id(value: Variant) -> bool
static func is_text(value: Variant, max_len: int) -> bool
```

```gdscript
class_name Catalog extends RefCounted                  # src/sim/catalog.gd: data/stats/, checked
static func check(towers: Variant, enemies: Variant, rules: Variant) -> PackedStringArray   # every problem; empty when valid
static func from_data(towers: Variant, enemies: Variant, rules: Variant) -> Catalog         # null when check() finds anything
func tower(id: StringName) -> TowerType                # null when unknown
func enemy(id: StringName) -> EnemyType                # null when unknown
func has_tower(id: StringName) -> bool
func has_enemy(id: StringName) -> bool                 # creatures and bosses
func tower_ids() -> Array[StringName]                  # file order
func enemy_ids() -> Array[StringName]                  # file order
var rules: GameRules

class_name TowerType extends RefCounted                # read only, in the file's units (2.6)
var id: StringName
var name: String
var plural: String
var info: String
var kind: StringName                                   # &"attack", &"slow" or &"boost"
var specs: Array[StringName]                           # the 2 path ids, spec 0 first
func stats(tier: int, spec: int) -> TowerStats         # tier 1 or 2 with spec -1; tier 3 with spec 0 or 1
func spec_name(spec: int) -> String
func spec_info(spec: int) -> String

class_name TowerStats extends RefCounted               # one stat block (2.6): cost, reach, hits_ground, hits_air, damage,
                                                       # reload_ms, splash, targets, pierce, slow_pct, slow_ms, boost_pct, boost_damage
class_name EnemyType extends RefCounted                # one creature (2.6), a field per key; summon, speed_up and release
                                                       # are Dictionaries, {} for none
class_name GameRules extends RefCounted                # rules.json (2.6), a field per key
```

```gdscript
class_name LevelData extends RefCounted                # src/sim/level_data.gd: one checked level or assembled run map
enum Kind { SCENERY, ROAD, SOCKET, SPOT, ENTRANCE, BASE }
const FORMAT: int = 1
const GRID_CHARS: String = ".#Go1234B"                 # the map characters of 2.3
const MAX_SPOTS: int = 24                              # the map and wave limits of 2.3 and 2.4
const MAX_SOCKETS: int = 8
const MAX_GROUPS: int = 8                              # groups in one wave
const SPAWN_BOUND: int = 120                           # creatures one wave spawns, counting splits
static func check(data: Variant, catalog: Catalog) -> PackedStringArray
static func from_data(data: Variant, catalog: Catalog) -> LevelData   # null when check() finds anything
func to_data() -> Dictionary                           # the file shape; from_data(to_data()) gives an equal level
func kind_at(cell: Vector2i) -> Kind                   # SCENERY outside the map
var id: StringName                                     # every field is read only
var name: String
var grid: PackedStringArray                            # the file's rows, for MapArt (3.9)
var rows: int                                          # columns is always Sim.MAP_COLUMNS
var entrances: Array[Vector2i]                         # index 0 is entrance 1 (A)
var base: Vector2i
var sockets: Array[Vector2i]                           # cell order
var spots: Array[Vector2i]                             # cell order
var start_gold: int
var gates: int
var strength: int
var towers: Array[StringName]
var star3: Dictionary                                  # {"kind": StringName, "value": int, "tower": StringName}
var hint_text: String                                  # "" for none
var hint_cell: Vector2i                                # (-1, -1) for none
var hint_button: StringName                            # &"call" or &""
var waves: Array[WaveData]
var twist_name: String                                 # "" for none (phase 7)
var twist_text: String
var twist_effects: Array[Dictionary]

class_name WaveData extends RefCounted                 # read only
var strength: int                                      # the level's, unless the wave sets its own
var groups: Array[WaveGroup]

class_name WaveGroup extends RefCounted                # read only
var enemy: StringName
var count: int
var entrance: int                                      # 0 based
var at_tick: int
var every_ticks: int
```

```gdscript
class_name RoadMap extends RefCounted                  # src/sim/road_map.gd: routing (section 4)
func _init(level: LevelData) -> void
func distances(closed: Array[Vector2i]) -> PackedInt32Array   # steps to the base per cell (index row * 7 + column); -1 when cut off or not road
func next_step(cell: Vector2i, dist: PackedInt32Array) -> Vector2i   # one step closer; ties: south, west, east, north
func route(from: Vector2i, dist: PackedInt32Array) -> Array[Vector2i]   # from a cell to the base, both included; empty when cut off
func seals(closed: Array[Vector2i]) -> bool            # true when any entrance has no open route
```

```gdscript
class_name Modifiers extends RefCounted                # src/sim/modifiers.gd: effects (2.8); the rest is internal to src/sim/
static func check(effects: Variant, catalog: Catalog, use: StringName) -> PackedStringArray   # use: &"twist", &"card" or &"risk"
static func normalize_all(effects: Array) -> Array[Dictionary]   # effects that passed check(), as plain data: ints, bools, Strings, [column, row] cells
static func group_count(effects: Array[Dictionary], count: int, flying: bool, last_wave: bool) -> int
                                                       # the count of a group in the wave data, with every count_pct of these
                                                       # normalized effects applied (2.8); at most Modifiers.COUNT_CEILING
                                                       # (1,000,000,000), clamped after every step, so no count overflows
```

Inside src/sim/, every stacked percent effect is clamped as it multiplies, so no product overflows: `speed_pct` at 1,000,000,000 percent, health, bounty and clear bonus scaling at 10^12, each `tower_pct` step in a tower's stats at 10^12, and starting gold at BIG (1,000,000,000) after each `start_gold_pct` step and after Relaxed.

```gdscript
class_name Battle extends RefCounted                   # src/sim/battle.gd: one map being defended
enum Phase { BUILD, WAVE, WON, LOST }
const FORMAT: int = 1
const DONE: StringName = &"done"                       # a command was carried out (not OK, which would shadow Godot's OK)
class Release extends RefCounted                       # inner class, internal: one batch of creatures being released at one
                                                       # spot (boss summons, Puffball splits, boss health releases); saved (5.6)

# Fixed for the whole battle. Read only.
var level: LevelData
var catalog: Catalog
var map: RoadMap
var relaxed: bool
var twist_effects: Array[Dictionary]                   # the Twist's effects (2.8) as plain checked data; [] for none

# State. Read only outside src/sim/.
var tick: int
var phase: Phase
var waves_started: int                                 # the next wave to start has this index
var running: Array[int]                                # indexes of the waves on the map, oldest first
var gold: int
var lives: int
var start_lives: int
var gates_in_hand: int
var gates: Array[GateState]                            # cell order
var towers: Array[TowerState]                          # cell order
var enemies: Array[EnemyState]                         # id order
var risk_waiting: Array[Dictionary]                    # a risk card's effects waiting for the next wave; [] for none
var card_effects: Array[Dictionary]                    # the kept card effects (2.8), in the order taken; instant ones are not kept
var gates_open: bool                                   # a `gates_open` risk effect holds every gate open until the next build phase (4.2)
var record_events: bool = true                         # bots set false for speed

static func create(level: LevelData, catalog: Catalog, relaxed: bool, twist_effects: Array[Dictionary]) -> Battle   # null on bad input (below)
func step() -> void                                    # one tick; does nothing unless phase is WAVE
func take_events() -> Array[Dictionary]                # the events since the last call, oldest first

# Player commands. Each returns DONE or a refusal, and a refusal changes nothing.
# Tower commands work in BUILD and WAVE, paused or not. Gate commands work in BUILD only.
func place_tower(cell: Vector2i, type: StringName) -> StringName
func upgrade_tower(cell: Vector2i, spec: int = -1) -> StringName   # spec 0 or 1 only from tier 2 to 3
func sell_tower(cell: Vector2i) -> StringName
func set_aim(cell: Vector2i, aim: TowerState.Aim) -> StringName
func place_gate(cell: Vector2i) -> StringName
func move_gate(from: Vector2i, to: Vector2i) -> StringName
func remove_gate(cell: Vector2i) -> StringName
func start_next_wave() -> StringName                   # from BUILD: starts the next wave; in WAVE: an early call with its bonus
func add_effects(effects: Array[Dictionary], risk: bool) -> StringName   # a picked card (phase 7); checked first
# Gold is held at most 1,000,000,000 (`BIG`, the most a save holds) at every gain: bounty, clear bonus, refund,
# early call bonus, `add_gold` and interest.

# Queries. Numbers are in the file's units (2.1): the UI divides by 100 for tiles and by 1000 for seconds.
func tower_at(cell: Vector2i) -> TowerState            # null for none
func enemy_with_id(id: int) -> EnemyState              # null for none
func build_options(cell: Vector2i) -> Array[Dictionary]   # [{"tower": StringName, "cost": int, "affordable": bool, "numbers": Dictionary}]
func tower_numbers(cell: Vector2i) -> Dictionary
func upgrade_options(cell: Vector2i) -> Array[Dictionary]   # one entry, or two at tier 3: {"spec": int, "cost": int, "refusal": StringName, "before": Dictionary, "after": Dictionary}
func sell_value(cell: Vector2i) -> int
func enemy_numbers(id: int) -> Dictionary
func closed_cells() -> Array[Vector2i]                 # the sockets closed to walkers right now
func routes(closed: Array[Vector2i]) -> Array[Dictionary]   # section 4.8
func seals(closed: Array[Vector2i]) -> bool
func wave_count() -> int
func wave_preview(index: int) -> Array[Dictionary]
func next_wave_info() -> Dictionary                    # {"refusal": StringName (&"" when it can start), "early": bool, "bonus": int}
func result() -> Dictionary                            # {"won": bool, "stars": int, "lives_left": int, "waves_cleared": int}; won and stars only once WON
func stars_possible() -> int                           # phase 7: the star bits a win from this moment could still earn (below)
func loses_star3(action: StringName, tower: StringName = &"", tier: int = 0) -> bool   # phase 7: would this action break star 3 (below)

# Save (section 5.6). All or nothing.
func to_data() -> Dictionary
static func from_data(data: Variant, catalog: Catalog) -> Battle   # null when any field is invalid
```

- `create` sets the starting numbers: a Twist's `start_gold_pct`, `set_lives`, `set_gates` and `fixed_gates` first, then Relaxed (RULES 11). Starting gold is held at most BIG. Lives come from rules.json. A run's map carries its own start gold, gates and towers (3.4).
- `create` returns null when the level or the catalog is missing, or when the Twist has more than 8 effects, fails `Modifiers.check` for use `twist`, has fixed gates that are not sockets of the level, outnumber the gates given (the level's, or the Twist's `set_gates`) or seal, or when any wave with the Twist alone (no risk card) passes a wave effect ceiling of 5.6, so no battle starts that no save of could load. Real data never does that: a level file holds at most 2 Twist effects, `LevelData.check` checks its fixed gates, and every real level's Twist stays far inside the ceilings (tests/save/). So a null is a bug.
- `twist_effects`, `card_effects` and `risk_waiting` hold checked effects as plain data: ints, bools, Strings (ids included), and cells as `[column, row]` arrays. `gates_open` is true from the start of a wave whose risk card holds `gates_open` until the next build phase begins, even after that wave is cleared.
- Tower numbers (`numbers`, `before`, `after` and `tower_numbers`) hold the tower's own stats with card effects: `damage`, `reload_ms`, `reach`, `splash`, `targets`, `pierce`, `slow_pct`, `slow_ms`, `hits_ground`, `hits_air`, `boost_pct`, `boost_damage`. `tower_numbers` adds `got_pct` and `got_damage` (the best Bakery boosts it gets), `boosting` (towers a Bakery boosts now), `spent`, `sell` and `aim`. The UI works out the rate as `(100 + got_pct) * 1000 / (100 * reload_ms)` attacks a second (RULES 5.2, 9.3).
- `enemy_numbers(id)`: `health`, `max_health`, `armor`, `speed` (now, with slows and effects), `base_speed`, `flying`, `lives`, `bounty`, `heal`, `slow_pct`, `slow_ms` (left), `bubble` (up), `bubble_ms` (until it is back), `breaking_ms` (left, 0 when not breaking). RULES 9.4.
- `wave_preview(index)`: one row per group in spawn order, `{"enemy": StringName, "count": int, "entrance": int (1 based), "health": int, "bounty": int, "heal": int}`, at that wave's strength with the Twist and, for the next wave, a waiting risk card applied (RULES 9.1).
- `result()["stars"]` holds bits: 1 for star 1, 2 for star 2, 4 for star 3 (2.7).
- `stars_possible()` (phase 7, for 2.7's stars during play): 0 once LOST. Otherwise bit 1, plus bit 2 on Normal while lives are at least `star2_lives`, plus bit 4 on Normal while the level's `star3` rule is not yet broken. For `no_lives_lost`, `towers_at_most`, `tower_ban`, `gates_at_most`, `tier_at_most`, `kinds_at_most` and `gates_whole` that means the record so far still meets the rule (2.7). For `early_calls_at_least` it means the early calls so far plus the waves not yet started can still reach N; in BUILD one fewer, since the next wave starts from a build phase. Once WON it equals `result()["stars"]`. On Relaxed it is at most 1.
- `loses_star3(action, tower, tier)` (phase 7): true only while bit 4 is in `stars_possible()` and the action would break it. `&"build"`: placing one more `tower` breaks `towers_at_most` with N towers standing, `tower_ban` of that tower, and `kinds_at_most` with N kinds built when `tower` is not one of them. `&"upgrade"`: a tower reaching `tier` breaks `tier_at_most` below `tier`. `&"gate"`: one more gate placed breaks `gates_at_most` with N already placed; the star is lost only if a wave starts that way. Every other action and kind gives false. Neither query changes anything.

```gdscript
class_name TowerState extends RefCounted               # src/sim/tower_state.gd, read only outside src/sim/
enum Aim { FIRST, LAST, STRONG }                       # RULES 8.2; FIRST is the default
var cell: Vector2i
var type: StringName
var tier: int                                          # 1, 2 or 3
var spec: int                                          # -1 below tier 3, else 0 or 1
var aim: Aim
var reload: int                                        # 1/100 ms until it may fire: 0 to stats.reload_ms * 100 between ticks; 0 is ready
var spent_now: int                                     # bought in the current build phase: refunded in full
var spent_before: int                                  # every other purchase: refunded at the refund percent
# Worked out again whenever towers or card effects change. Render reads these for boost marks.
var kind: StringName                                   # &"attack", &"slow" or &"boost", from its type
var stats: TowerStats                                  # its own stats with card effects, before Bakery boosts; shared, never write to it
var got_pct: int                                       # the best Bakery rate boost it gets; 0 for Bells and Bakeries
var got_damage: int                                    # the best Bakery damage bonus it gets; 0 for Bells and Bakeries
var boosting: int                                      # a Bakery: the attacking towers it boosts now; 0 for other towers

class_name EnemyState extends RefCounted               # src/sim/enemy_state.gd
var id: int
var type: StringName
var wave: int
var health: int
var max_health: int
var bubble: bool                                       # the bubble is up
var slow_pct: int
var slow_ticks: int
var flying: bool
var breaker: bool                                      # walks the breaker route (4.5)
var from_cell: Vector2i                                # walkers: the step being walked
var to_cell: Vector2i
var progress: int                                      # sub-units along the step, 0 to UNIT
var fly_from: Vector2i                                 # flyers: a straight line in sub-units
var fly_to: Vector2i
var fly_length: int
var flown: int
var breaking: int                                      # 1/100 ms of breaking left; 0 when not breaking
var pos: Vector2i                                      # sub-units, after this tick
var prev_pos: Vector2i                                 # sub-units, after the last tick

class_name GateState extends RefCounted                # src/sim/gate_state.gd
var cell: Vector2i
var fixed: bool                                        # cannot be moved or removed
var broken: bool                                       # broken; mends, closed, when the next build phase begins
```

Refunds (RULES 4.6): a purchase in a build phase goes into `spent_now`. A purchase during a wave, paused or not, goes into `spent_before`. When a wave starts, `spent_now` moves into `spent_before`. A sale refunds `spent_now` plus `spent_before * refund_pct / 100`, rounded down.

#### Refusals

| Refusal | When |
|---|---|
| `&"over"` | The battle is WON or LOST. |
| `&"not_a_spot"`, `&"occupied"` | No build spot there, or it has a tower. |
| `&"not_offered"` | The level or run does not offer that tower, or a Twist bans it. |
| `&"too_poor"` | Not enough gold. |
| `&"no_tower"` | No tower there. |
| `&"top_tier"`, `&"tier_cap"` | Already tier 3, or a Twist caps the tier. |
| `&"pick_spec"`, `&"bad_spec"` | Tier 2 to 3 needs spec 0 or 1; other steps take -1. |
| `&"no_selling"` | A Twist forbids selling. |
| `&"no_aim"` | Bells and Bakeries have no targeting. |
| `&"bad_aim"` | The aim value is not FIRST, LAST or STRONG. |
| `&"gates_locked"` | A gate command outside BUILD. The UI says "Gates are locked until the wave is over." (RULES 7.6) |
| `&"not_a_socket"`, `&"has_gate"`, `&"no_gate"` | No socket there, the socket has a gate, or no gate there. |
| `&"no_gates_left"` | No gate in hand. |
| `&"fixed_gate"` | That gate cannot be moved or removed. |
| `&"would_seal"` | Some entrance would lose its last open route. The UI says "That would close every road." (RULES 7.4) |
| `&"no_more_waves"` | Every wave has started. |
| `&"still_spawning"` | The newest wave has not spawned all its groups (RULES 4.9). |
| `&"too_many_waves"` | `max_waves_running` waves are on the map. |
| `&"risk_waiting"` | A risk card is already waiting. |
| `&"bad_effect"` | The list is empty or fails `Modifiers.check` (2.8), an `add_group` entrance is not on this map, or the battle would hold more than 64 kept card effects or a risk card of more than 8 effects; or a risk card would take the next wave past a wave effect ceiling of 5.6, or a card's kept effects would take a tower stat or a gold gain past a kept effect ceiling of 5.6, so play never makes a save that will not load. A refused card changes nothing, instant effects included. |

The UI turns every other refusal into plain feedback of its own.

#### Events

Each event is a Dictionary with `"kind"` and the fields below. Commands add events too, so render and audio handle everything in one place. Wave numbers are 0 based. Events that render or audio must tell apart carry the ids they need: `fired` carries the tower id and its tier 3 path, because the paths fire different things (pebbles or a boulder, one rocket or a burst) and audio has no Battle to look them up. Only attacking towers emit `fired`, once per shot. The Lullaby Bell and the Bakery never fire (RULES 5.1), and no other event stands in for them: in battle they make no sound of their own beyond `built`, `upgraded` and `sold`.

| kind | Fields |
|---|---|
| `&"wave_started"` | `wave: int`, `early: bool` |
| `&"spawned"` | `id: int`, `enemy: StringName`, `pos: Vector2i` |
| `&"fired"` | `cell: Vector2i` (the tower's cell), `tower: StringName` (the tower id), `spec: int` (-1 below tier 3), `targets: Array[int]`, `at: Array[Vector2i]` (each target's position when hit) |
| `&"popped"` | `id: int` (a bubble popped) |
| `&"defeated"` | `id: int`, `enemy: StringName`, `pos: Vector2i`, `gold: int` |
| `&"released"` | `id: int` and `source: StringName` (the releaser, which may already be gone from the state), `enemy: StringName` (the creature released), `count: int`, `pos: Vector2i` (where the release begins). Sent when any release begins: a Puffball's split when it is defeated, each batch of a boss's summons, and a boss's health release (Old Tusk's). Each creature released later gets its own `spawned`. |
| `&"healed"` | `id: int` (the Mender), `ids: Array[int]` (the first 6, `Battle.HEAL_EVENT_IDS`, of the creatures that gained health, in id order. Every creature in reach still gains it. No event when none did). The render marks at most that many. |
| `&"sped_up"` | `id: int`, `speed: int` (the new speed in hundredths of a tile a second: its data speed plus its speed ups, before slows and `speed_pct`, the same as `base_speed` in `enemy_numbers`) |
| `&"leaked"` | `id: int`, `enemy: StringName`, `lives: int` |
| `&"break_started"` | `id: int` (the breaker), `cell: Vector2i` (the gate's own cell, as in `gate_broken`). Sent when the breaker reaches the center of the cell before that gate and starts to break it. |
| `&"gate_broken"` | `cell: Vector2i` |
| `&"wave_cleared"` | `wave: int`, `gold: int` (the clear bonus, plus a risk card's `reward_gold` for that wave) |
| `&"interest"` | `gold: int` (the gold `interest` adds, 2.8). Sent just before `build_started`, only when more than 0. |
| `&"build_started"` | `wave: int` (the next wave) |
| `&"built"`, `&"upgraded"`, `&"sold"` | `cell: Vector2i`, `tower: StringName`, `tier: int`, `spec: int`, `gold: int` |
| `&"gate_placed"`, `&"gate_removed"` | `cell: Vector2i` (a move is a removal, then a placement) |
| `&"won"`, `&"lost"` | none |

### 3.2 How render and UI read the sim and send commands

BattleScreen (ui-engineer) is the only place that steps the sim and drains its events. Each frame:

```gdscript
func _process(delta: float) -> void:
	if battle.phase == Battle.Phase.WAVE:
		for i: int in clock.advance(delta):              # whole ticks, none while paused (BattleClock, 3.6)
			battle.step()
	else:
		clock.reset()
	var events: Array[Dictionary] = battle.take_events()
	map_view.sync(clock.alpha())                       # reads battle state, draws between prev_pos and pos
	map_view.play_events(events)                       # projectiles, puffs, sparkles, gate effects
	audio.play_events(events)
	hud.refresh(battle)                                # gold, lives, wave, the call button and its bonus
	_handle(events)                                    # build_started: save_requested; won or lost: ended
```

- Render and UI only read `Battle` fields and the state objects. Player actions are command calls made between frames, so each lands between two ticks.
- Drawing between ticks: `lerp(Vector2(prev_pos), Vector2(pos), alpha)`, scaled from sub-units to map pixels.
- A hit lands in the sim on the tick the tower fires. The render draws a projectile from the tower to `at` and may hold the hit flash or the puff until it arrives (RULES 5.2). The creature hit may already be gone from the state.
- Inspect panels call the query methods every frame while open. That is cheap.
- On a fold or any resize only the layout changes (7.5).

### 3.3 How the balance bots drive the sim

tools/balance/ (balance-analyst) uses the public API only, with no UI and no class names of its own:

```gdscript
var game: GameData = GameData.load_from("res://data")
var level: LevelData = game.levels[&"r1_l1"]
var battle: Battle = Battle.create(level, game.catalog, false, [])
battle.record_events = false
while battle.phase != Battle.Phase.WON and battle.phase != Battle.Phase.LOST:
	bot.plan(battle)                                   # build, upgrade, sell, aim, gates; the bot's own seeded generator
	battle.start_next_wave()
	while battle.phase == Battle.Phase.WAVE:
		bot.react(battle)                              # optional commands and early calls between ticks
		battle.step()
var outcome: Dictionary = battle.result()
```

- A copy for trying a branch: `Battle.from_data(battle.to_data(), game.catalog)`.
- Same input check: play twice with the same bot seed and compare `result()` and `JSON.stringify(battle.to_data())`.
- Twists (phase 7): pass `level.twist_effects` to `create`.
- Runs and the daily (phase 7), the same loop through the session:

```gdscript
var session: RunSession = RunSession.start(run_seed, "", false, game.run.pool(counters), game.run, game.catalog)
# the daily: RunSession.start(RunSeeds.daily_seed(day), day, false, game.run.card_ids(), game.run, game.catalog)
var battle: Battle = session.battle
battle.record_events = false
while battle.phase != Battle.Phase.WON and battle.phase != Battle.Phase.LOST:
	while session.draft_open():
		session.pick(bot.choose(session.offers()))     # the bot's own seeded generator
	bot.plan(battle)
	session.start_next_wave()
	while battle.phase == Battle.Phase.WAVE:
		bot.react(session)                             # early calls only through session.start_next_wave()
		battle.step()
var outcome: Dictionary = session.result()
```

- Same input check for runs: play twice with the same run seed and bot seed, and compare `session.result()`, `JSON.stringify(battle.to_data())` and `JSON.stringify(session.to_data())`.
- Each bot run prints its seeds, so every number in a docs/balance/ report can be repeated.

### 3.4 Runs, cards and the daily: src/run/ (roguelite-engineer, phase 7)

Seeds:

- A normal run's seed is drawn by the App: `randi()` from a freshly randomized `RandomNumberGenerator`, 0 to 2^32 - 1. It is the only unseeded draw in the game, and it is saved with the run.
- The daily seed is the local date as YYYYMMDD, for example 20261023 (RULES 15). The App reads the date with `Time.get_date_dict_from_system()` and passes the day key in. src/run/ never reads the clock.
- Every other generator is a `RandomNumberGenerator` from `MapAssembler.generator()`, whose `seed` is set to `RunSeeds.derive(run_seed, tag, index)`, which is `("%d:%s:%d" % [run_seed, tag, index]).hash()`. Tags and indexes: `"map"` 0, `"boss"` 0, `"pack"` the band (1 to 6), `"draft"` the wave the draft follows (1 to 17). A test pins a few values, so an engine change to `String.hash()` is caught.
- Only `randi_range()` is called on these generators, in exactly the order written below. So the map, the boss and the waves depend only on the run seed, and a draft only on the run seed and the cards eligible when it opens. Earlier picks never change a later draft's generator (RULES 14.4).

Building a run, `MapAssembler.assemble()`:

1. Boss, generator `"boss"` 0: over the bosses that have a band 6 pack, in enemies.json order, `randi_range(0, n - 1)`.
2. Map, generator `"map"` 0: a top segment by `randi_range(0, n - 1)` over every top in index order; then a middle the same way over the middles that fit under it; then a bottom over the bottoms that fit under that middle (2.9).
3. Packs, generator `"pack"` b for each band b from 1 to 6: `randi_range(0, n - 1)` over that band's packs in packs.json order; for band 6, only the packs naming the boss.
4. Waves: band b's pack gives waves 3b - 2, 3b - 1 and 3b, in its order. Every wave carries its own `strength`: waves 1 to 17 get `strength_start + strength_step * (w - 1)`, and wave 18 gets its band 6 pack's boss wave strength (2.9). On a map with one entrance, entrance 2 becomes entrance 1.
5. The level: `{"format": 1, "id": "run", "name": "Run", "grid": <the top, middle and bottom rows in order>, "start_gold", "gates" and "towers" from run.json, "strength": <strength_start>, "star3": {"kind": "no_lives_lost"}, "waves": <the 18 waves>}`, with no hint and no Twist, through `LevelData.from_data`. The level's `strength` is `strength_start`, though every wave sets its own. Runs have no stars: `star3` is there only because the level shape needs one, and nothing shows it or the name. A map whose build spots or gate sockets fall outside run.json's `spots` and `sockets` gives null too (2.9). A null result is a data bug: `RunSession.start` returns null, and the App shows the damaged message of 2.12.

Drafts (RULES 14.4):

- Owed drafts are worked out from the battle, so nothing extra is saved. Wave index w (0 based) is cleared when `w < battle.waves_started` and `battle.running` does not hold w. Each cleared wave among waves 1 to 17 (indexes 0 to 16) owes one draft. Drafts are picked in wave order, so the open draft always follows wave `picks.size() + 1`, and `drafts_owed()` is the cleared waves among waves 1 to 17 less `picks.size()`, never below 0. In BUILD every started wave is cleared, so that is `mini(battle.waves_started, 17) - picks.size()`.
- `draft_open()`: a draft is owed (`drafts_owed() > 0`) and the battle is in BUILD. A draft with no build phase after it never opens.
- `start_next_wave()`: `&"draft_waiting"` while a draft is owed, in either phase; else `battle.start_next_wave()`. The UI says "Pick your card after this wave." during a wave and "Pick a card first." in a build phase.
- Eligible cards when a draft opens are the pool's cards, less every `once` card already picked, and:
  - a tower card only while its tower is not in the run. The run's towers are run.json `towers` plus the tower of every tower card picked;
  - a perk only while its tower is in the run;
  - a perk with an unlock condition (RULES 14.6) only while no perk without one is eligible;
  - a gate card only while the run's gates, placed and in hand, are fewer than `max_gates` and fewer than the map's sockets;
  - economy cards always;
  - a risk card only while `battle.risk_waiting` is empty and wave 17 has not started (`battle.waves_started < 17`). So the boss wave is never changed, even when wave 17 was called early and the draft after wave 16 opens after it.
- The draw, on generator `"draft"` w, slot by slot, at most 3 slots:
  1. Slot 1, while the run has fewer than 3 towers and a tower card is eligible: a tower card, with no type draw.
  2. Otherwise the types with an eligible card not yet offered, in the order tower, perk, gate, economy, risk, leaving out any type of weight 0: `r = randi_range(1, the sum of their weights)`, and the type is the first whose running sum of weights reaches r. After a risk card is offered, risk is left out for the rest of the draft.
  3. The card: `randi_range(0, n - 1)` over that type's eligible cards not yet offered, in cards.json order.
  4. When no type has a card left, the draft offers fewer than 3.
- A pool must hold at least one economy card that is not `once`. Economy cards are always eligible, and run.json's economy weight is at least 1 (2.10), so a draft is never empty. `RunSession.start` returns null and `RunSession.from_data` refuses a save whose pool lacks one. The real pools hold `gold_purse` and `tea_break`.
- Offers are worked out again whenever asked and are not saved. Nothing a player can do in a build phase changes eligibility before the pick, so a restored run shows the same offers.
- `pick(card_id)`: only a card in `offers()`. It calls `battle.add_effects(effects, risk)`, with `risk` true for a risk card, and when that returns `Battle.DONE` it appends the id to `picks`. It returns `Battle.DONE`, `&"not_offered"`, or the battle's refusal. `RunSession.from_data` also ties the battle to the picks (5.6).
- The pool is fixed when the run starts and is saved with it: the App passes `RunData.pool(progress.unlock_counters())` for a normal run and `RunData.card_ids()` for the daily (RULES 15).

```gdscript
class_name RunSeeds extends RefCounted                 # src/run/run_seeds.gd
static func derive(run_seed: int, tag: String, index: int) -> int
static func day_key(date: Dictionary) -> String        # a Time date dictionary to "2026-10-23"; "" without a whole year, month and
                                                       # day. Check the result with is_day_key().
static func is_day_key(text: String) -> bool           # a real calendar date from 2026-01-01 to 2200-12-31
static func daily_seed(day: String) -> int             # "2026-10-23" to 20261023; -1 when day is not a day key
static func day_number(day: String) -> int             # days since 1970-01-01, for "the day after"; -1 when day is not a day key

class_name RunData extends RefCounted                  # src/run/run_data.gd: segments, packs, run plan and cards, checked. Read only.
const BANDS: int = 6                                   # 3 waves each: 18 waves and 17 drafts (2.10)
static func check(files: Dictionary, catalog: Catalog) -> PackedStringArray   # files: 2.12
static func from_data(files: Dictionary, catalog: Catalog) -> RunData         # null when check() finds anything
# run.json (2.10)
var strength_start: int
var strength_step: int
var start_gold: int                                    # Normal
var gates: int
var towers: Array[StringName]                          # the towers a run starts with
var rows: Dictionary                                   # {"top": int, "middle": int, "bottom": int}
var spots_min: int                                     # spots [lo, hi]
var spots_max: int
var sockets_min: int                                   # sockets [lo, hi]
var sockets_max: int
var bands: Array[Array]                                # 6 lists of creature ids (StringName), band 1 first
var weights: Dictionary[StringName, int]               # card kind (&"tower", &"perk", &"gate", &"economy", &"risk") to its draft weight
# The other files, each in its file's order
var segment_ids: Array[StringName]                     # index.json
var packs: Array[Dictionary]                           # packs.json, in the pack shape below
var cards: Array[Dictionary]                           # cards.json, in the card shape below
func card(id: StringName) -> Dictionary                # the card shape; {} when unknown
func card_ids() -> Array[StringName]                   # cards.json order
func pool(counters: Dictionary) -> Array[StringName]   # 2.11, cards.json order; counters as Progress.unlock_counters(), a missing one is 0
func segment(id: StringName) -> Dictionary             # the segment shape; {} when unknown
func segments_of(kind: StringName) -> Array[Dictionary]   # &"top", &"middle" or &"bottom", in index order
func segments_under(upper_id: StringName) -> Array[Dictionary]   # the middles that fit under a top, or the bottoms under a middle (2.9),
                                                       # in index order; [] under a bottom or an unknown id
func packs_of(band: int, boss: StringName = &"") -> Array[Dictionary]   # one band's packs in packs.json order; with a boss, only the
                                                       # band 6 packs naming it
func boss_ids() -> Array[StringName]                   # the bosses that have a band 6 pack, in enemies.json order

class_name MapAssembler extends RefCounted             # src/run/map_assembler.gd
static func assemble(run_seed: int, data: RunData, catalog: Catalog) -> LevelData   # plan(), then build(); null on a data bug or a seed
                                                       # outside 0 to 2^32 - 1
static func plan(run_seed: int, data: RunData) -> Dictionary   # steps 1 to 3: {"boss": StringName, "top": StringName, "middle": StringName,
                                                       # "bottom": StringName, "packs": Array[StringName] (one per band, band 1 first)};
                                                       # {} when data is null, the seed is outside 0 to 2^32 - 1, or a pick has
                                                       # nothing to choose from
static func build(data: RunData, catalog: Catalog, top_id: StringName, middle_id: StringName, bottom_id: StringName, pack_ids: Array[StringName]) -> LevelData
                                                       # steps 4 and 5 for these segments and one pack per band, band 1 first; null below
static func generator(run_seed: int, tag: String, index: int) -> RandomNumberGenerator   # seeded with RunSeeds.derive(run_seed, tag, index)

class_name RunCards extends RefCounted                 # src/run/run_cards.gd: the card checks of 2.11, internal except:
static func has_stat(tower: TowerType, stat: String) -> bool   # the tower's kind has the stat, as 2.11's perk rule reads it

class_name RunPacks extends RefCounted                 # src/run/run_packs.gd: the pack checks of 2.9, internal except:
static func spawn_total(groups: Array, catalog: Catalog, effects: Array[Dictionary]) -> int
                                                       # creatures one wave spawns, counting split_count for each splitter: groups in the
                                                       # pack shape, with a risk card's normalized effects ([] for none) applied as 2.8 says

class_name RunSession extends RefCounted               # src/run/run_session.gd: one run around its Battle
const FORMAT: int = 1
static func start(run_seed: int, day: String, relaxed: bool, pool: Array[StringName], data: RunData, catalog: Catalog) -> RunSession
                                                       # day "" for a normal run. A daily passes a day key, run_seed equal to
                                                       # RunSeeds.daily_seed(day), and relaxed false. null when the seed is
                                                       # outside 0 to 2^32 - 1, when a daily breaks its rules, when the pool is
                                                       # not 1 to 256 known cards with no repeats or holds no economy card that
                                                       # is not once, or when the map cannot be built.
var battle: Battle                                     # every field is read only
var run_seed: int
var daily: bool                                        # day is not ""
var day: String                                        # the day a daily belongs to; "" for a normal run
var pool: Array[StringName]
var picks: Array[StringName]                           # in pick order
func drafts_owed() -> int                              # the cleared waves among waves 1 to 17, less the picks made; never below 0
func draft_open() -> bool                              # drafts_owed() > 0 and the battle is in BUILD
func offers() -> Array[StringName]                     # the open draft's cards, 1 to 3; [] when no draft is open
func pick(card_id: StringName) -> StringName
func card(id: StringName) -> Dictionary                # the card's data from RunData (the card shape below); {} when unknown
func start_next_wave() -> StringName
func risk_card() -> StringName                         # the picked risk card still waiting for its wave; &"" for none
func result() -> Dictionary                            # {"won": bool, "waves": int, "lives": int, "reached": int, "risks": int}
func to_data() -> Dictionary                           # 5.5, without the battle
static func from_data(data: Variant, battle: Battle, run_data: RunData) -> RunSession   # 5.6; null when invalid, a pool with no
                                                       # economy card that is not once included

class_name Daily extends RefCounted                    # src/run/daily.gd: RULES 15
const STREAK_MAX: int = 100000                         # the streak ceiling of 5.5
static func is_better(a: Dictionary, b: Dictionary) -> bool   # a win beats a loss; between wins more lives; between losses more waves;
                                                       # a tie keeps b. An empty b is no result yet, which any a beats; an empty a
                                                       # never wins. A field of the wrong type counts as false or 0.
static func streak_after(streak: int, last_day: String, day: String) -> Dictionary   # {"streak": int, "day": String}
static func shown_streak(streak: int, last_day: String, today: String) -> int        # 0 unless last_day is today or yesterday
```

- The shapes RunData returns. Each getter returns a copy; `packs` and `cards` are the held arrays, read only.
  - Card: `{"id": StringName, "kind": StringName, "tower": StringName (&"" for none), "name": String, "text": String, "once": bool, "unlock": {} or {"counter": String, "at": int}, "effects": Array[Dictionary]}`, the effects as checked plain data (`Modifiers.normalize_all`).
  - Segment: `{"id": StringName, "kind": StringName, "grid": PackedStringArray, "top_ports": Array[int], "bottom_ports": Array[int], "spots": int, "sockets": int}`. Ports are columns (2.9). A top segment's `top_ports` and a bottom segment's `bottom_ports` are empty.
  - Pack: `{"id": StringName, "band": int, "boss": StringName (&"" in bands 1 to 5), "waves": Array}`, 3 waves, each `{"groups": Array}` of `{"enemy": String, "count": int, "entrance": int (1 or 2), "at_ms": int, "every_ms": int}`, in the file's units. A band 6 pack's third wave, the boss wave, also holds `"strength": int` (2.9).
- `MapAssembler.build()` returns null when data or the catalog is missing, a segment is unknown or of the wrong kind, `pack_ids` is not one known pack per band in band order, the band 6 pack's boss wave has no `strength`, the level fails `LevelData.check`, or its build spots or gate sockets fall outside run.json's `spots` and `sockets`. It does not check that the segments fit (2.9): pick them with `segments_under()`.
- `RunPacks.spawn_total()`: `count_pct` scales the given groups, and an `add_group` group comes at its card's count (2.8). This is the count 2.9's spawn bound limits.
- RunSegments (src/run/run_segments.gd) is internal to src/run/.
- `RunSession.result()`: `won` is true once the battle is WON; `waves` the waves cleared (`battle.result()["waves_cleared"]`); `lives` the lives left, at least 0; `reached` the highest wave number started (`battle.waves_started`); `risks` the risk cards picked. The App uses it for an abandoned run too, which counts as lost at its current wave (RULES 14.7).
- `Daily.streak_after`: the day after `last_day` adds 1 and moves the day; `last_day` itself or an earlier day changes nothing; anything else, `""` included, starts again at 1 on `day`. A `day` that is not a day key changes nothing. The streak never goes past `Daily.STREAK_MAX`.
- A daily run belongs to the day it started, even if it ends after midnight (RULES 15). If the phone's date is not a day key (before 2026-01-01 or after 2200-12-31), the Daily button says "Check the phone's date." and starts no new daily. A saved daily still resumes.

### 3.5 Files and saves: src/save/ (sim-engineer)

```gdscript
class_name JsonFile extends RefCounted                 # src/save/json_file.gd: the only JSON file reader and writer
## {"status": StringName, "data": Variant, "text": String}. Status: &"ok", &"missing", &"locked" (exists, cannot be opened)
## or &"bad" (over max_bytes, a NUL byte or a byte of 0x80 or above, or not valid JSON). "data" is null and "text" "" unless ok.
static func read(path: String, max_bytes: int) -> Dictionary
static func probe(path: String) -> StringName          # &"missing", &"locked" or &"ok" (it opens); reads nothing
static func is_ascii(bytes: PackedByteArray) -> bool   # no NUL byte and no byte of 0x80 or above
static func to_text(data: Dictionary) -> String        # JSON with sorted keys; "" when it is not plain ASCII
static func write_atomic(path: String, data: Dictionary, backup_of: String = "") -> bool   # section 5.3; only inside user://
                                                       # backup_of: the text the caller last wrote or loaded as valid at path
static func write_text(path: String, text: String, backup_of: String = "") -> bool   # write_atomic for text from to_text()
static func remove(path: String) -> bool               # true when no file is there afterwards

class_name GameData extends RefCounted                 # src/save/game_data.gd: every bundled data file, checked (2.12)
static func load_from(root: String = "res://data") -> GameData
var problems: PackedStringArray                        # empty when every file is valid
var catalog: Catalog
var campaign: Array[Dictionary]                        # [{"id": StringName, "name": String, "levels": Array[StringName]}]
var levels: Dictionary[StringName, LevelData]
var run: RunData                                       # from the files of 2.12; null when any run file has a problem

class_name SaveStore extends RefCounted                # src/save/save_store.gd: every save file (section 5)
func _init(dir: String = "user://") -> void            # tests pass a folder under user://tests/; one outside user:// is refused
func load_settings() -> Settings
func save_settings(settings: Settings) -> bool
func load_progress() -> Progress
func save_progress(progress: Progress) -> bool
func load_games(game: GameData) -> Array[SavedGame]    # every valid saved game, most recent first; an invalid one is deleted
func save_game(saved: SavedGame) -> bool               # gives it the next order number, then writes its mode's file; false when
                                                       # can_save() is false or the write failed
func delete_game(mode: StringName) -> void
func is_locked(file_name: String) -> bool              # true when this launch leaves that file alone (5.4), for example "progress.json"
func load_daily() -> DailyRecord
func save_daily(daily: DailyRecord) -> bool

class_name Settings extends RefCounted                 # src/save/settings.gd
var sound_on: bool = true
func to_data() -> Dictionary
static func from_data(data: Variant) -> Settings       # any bad field falls back to its default

class_name Progress extends RefCounted                 # src/save/progress.gd
var levels: Dictionary[StringName, int]                # level id to star bits 0 to 7, the union of every win
var twists: Array[StringName]                          # levels whose Twist was won
var seen: Array[StringName]                            # towers, creatures and levels whose card or hint already showed by itself
var counters: Dictionary[StringName, int]              # the five counters of RULES 14.6 (5.5)
func record_level(id: StringName, bits: int) -> void
func record_twist(id: StringName) -> void
func mark_seen(id: StringName) -> void
func bump(counter: StringName, amount: int) -> void    # adds, saturating at the ceiling
func raise(counter: StringName, value: int) -> void    # keeps the larger value, for best_run_wave
func stars() -> int                                    # star marks over every recorded level, unknown ids included (5.5)
func cleared(id: StringName) -> bool                   # the level was won at least once (star bit 1)
func level_open(game: GameData, id: StringName) -> bool   # RULES 16
func region_open(game: GameData, index: int) -> bool
func runs_open(game: GameData) -> bool                 # the roguelite and the daily
func twist_open(id: StringName) -> bool                # 3 stars on that level
func unlock_counters() -> Dictionary                   # the counters plus "stars" and "twists_cleared", for RunData.pool (phase 7)
func to_data() -> Dictionary
static func from_data(data: Variant) -> Progress

class_name SavedGame extends RefCounted                # src/save/saved_game.gd: one level or run in progress
const LEVEL: StringName = &"level"                     # the modes; also RUN (&"run") and DAILY (&"daily")
var mode: StringName                                   # &"level", &"run" or &"daily"
var order: int                                         # higher is more recent; SaveStore sets it
var level_id: StringName                               # the campaign level; &"" for runs
var twist: bool
var battle: Battle
var run: RunSession                                    # the RunSession around battle for modes run and daily; null for a campaign level
func can_save() -> bool                                # a known mode and a battle in BUILD or WAVE; a run or daily also needs its run
                                                       # around this battle, a daily with a day and a run without; a campaign level
                                                       # has no run
func to_data() -> Dictionary                           # the 5.5 shape
static func from_data(data: Variant, game: GameData) -> SavedGame   # null when any field is invalid (5.5, 5.6); a run or daily
                                                       # needs game.run

class_name DailyRecord extends RefCounted              # src/save/daily_record.gd
var day: String                                        # "" or the day of `best`
var best: Dictionary                                   # that day's best {"won": bool, "waves": int, "lives": int}; {} for none
var streak: int
var streak_day: String                                 # the last counted day
func record_finish(day: String, result: Dictionary) -> void   # uses Daily.is_better and Daily.streak_after
func to_data() -> Dictionary
static func from_data(data: Variant) -> DailyRecord
```

- `DailyRecord.record_finish(day, result)`: `day` is the day the finished daily belongs to, and `result` is `{"won", "waves", "lives"}` from `RunSession.result()`; other keys are ignored. A `day` that is not a day key changes nothing. The streak becomes `Daily.streak_after(streak, streak_day, day)`. The result is kept as a bool and two ints from 0 to 1,000: a missing field, or one of the wrong type, counts as false or 0, as `Daily.is_better` reads it. The best: a `day` later than the record's `day` (or a record with none) replaces it; the same day keeps the better of the two by `Daily.is_better`; an earlier day leaves it alone. Day keys compare as text, which is date order.
- The Daily button shows `best` only while the record's `day` is today, and the streak through `Daily.shown_streak`.

### 3.6 Screens and app glue: src/ui/, scenes/ui/ (ui-engineer)

```gdscript
class_name App extends Control                         # src/ui/app.gd, root of scenes/ui/app.tscn
## Creates GameData, SaveStore, Settings, Progress, the saved games and AudioService once and passes them down with setup().
## Routes between screens, saves on lifecycle notifications, handles the back button.
signal sound_changed(on: bool)                         # the Settings toggle
signal continue_requested()                            # the mode screen's taps; the battle flow answers them (Roguelite and Daily from U3)
signal campaign_requested()
signal roguelite_requested()
signal daily_requested()
func build() -> void                                   # the layers and the front door; _ready calls it, tests may call it first
func apply_layout(window: Vector2, safe: Rect2) -> void   # lays out every screen and modal; called on every resize
func handle_back() -> StringName                       # &"modal", &"page", or &"quit" when nothing is left (the caller quits)
func push_screen(screen: ScreenFrame) -> void          # only the top screen shows
func pop_screen() -> void                              # the front door is never removed
func current_screen() -> ScreenFrame
func open_modal(modal: Modal) -> void                  # above every screen; the App frees it when it closes
func top_modal() -> Modal                              # null for none
func open_mode() -> void
func open_info() -> void
func open_settings() -> void

class_name Layout extends RefCounted                   # src/ui/layout.gd (section 7); logical px of the 1080 wide base
const LANDSCAPE_BELOW: float = 1.5
const MIN_TOUCH: float = 160.0                         # at least 48 dp on every screen in 7.4
const PAD: float = 36.0                                # outer padding of every screen, inside the safe area
const CONTENT_MAX: float = 1100.0                      # text pages never get wider
static func is_landscape(window_size: Vector2) -> bool # height < 1.5 x width
static func safe_rect(viewport: Viewport) -> Rect2     # the display safe area in viewport coordinates
static func safe_in_viewport(full: Vector2, window_px: Vector2, window_pos: Vector2, safe_screen: Rect2) -> Rect2   # the pure part of safe_rect, for tests
static func content_width(window_width: float, safe: Rect2) -> float   # the safe width less padding, capped at CONTENT_MAX

class_name BattleClock extends RefCounted              # src/ui/battle_clock.gd: real time to whole ticks, counted in whole microseconds
var speed: int = 1                                     # 1, 2 or 3; every level and run starts at 1 (RULES 4.8)
var paused: bool = false
const TICK_US: int = 50000                             # one tick, Sim.MS_PER_TICK
const MAX_FRAME_US: int = 250000                       # a long frame or a return from the background never bursts
const MAX_TICKS_PER_FRAME: int = 6
func advance(delta: float) -> int                      # whole ticks to run now; 0 while paused
func alpha() -> float                                  # 0 to 1: how far between the last tick and the next
func reset() -> void                                   # drops the leftover time

class_name BattleScreen extends ScreenFrame            # src/ui/battle_screen.gd: map, HUD, panels, input
signal save_requested()                                # a build phase began, a card was picked, the HUD pause button paused the game, or Pause opened
signal ended(result: Dictionary)                       # won, lost, or abandoned from Pause after a confirm (then won is false). result is
                                                       # Battle.result() plus "abandoned", "relaxed" and "twist" (the battle has Twist effects)
signal left()                                          # "Back to menu" in Pause; the game stays saved
var stars_in_play: bool = true                         # false in a run or daily (set_run sets it). Star lines and star warnings
                                                       # need it true and a battle with no Twist.
func setup(battle: Battle, audio: AudioService, progress: Progress) -> void
func set_run(run: RunSession) -> void                  # after setup(): this battle is a run or daily (below)
func apply_layout(window: Vector2, safe: Rect2) -> void   # from ScreenFrame; the App calls it on every resize (7.5)
func pause() -> void                                   # freezes the clock and opens Pause
func is_paused() -> bool

class_name Links extends RefCounted                    # src/ui/links.gd (section 8)
```

- ScreenFrame (every full screen) and Modal (Settings, Pause, the confirm dialog) are the base classes in src/ui/. BattleScreen opens PausePanel with `App.open_modal()`, and Info and Settings with `open_info()` and `open_settings()`. Other App members are internal.
- The other screens are used only inside src/ui/, so their signals can change without a contract change: FrontDoor, ModeScreen (the Continue card, Campaign, Roguelite, Daily), LevelSelect, LevelCard (RULES 10.5: name, waves, gates, the three star lines, stars earned, the hint, Normal or Relaxed with Normal always preselected, the Twist once open), WavePreview, InfoCard (first sight), PausePanel (Resume, Info, Settings, "Back to menu" with the game kept saved, "Abandon" after a confirm, the quiet coffee row), SettingsPanel (sound, About), InfoScreen, AboutScreen, EndPanel, ConfirmDialog, and in phase 7 RunCard, DraftPanel and RunEndPanel.
- `BattleScreen.set_run(run)`: call it after `setup()`. It sets `stars_in_play` false, so Pause shows no star lines and nothing warns about stars. Every call of the next wave goes through `run.start_next_wave()`. While a card is owed, the call button says "Pick a card first" in a build phase or "Card due after this wave" during a wave, with the locked look, and a tap shows the sentence of 3.4. Card names and texts come from `run.card()`, and the owed count from `run.drafts_owed()`.
- Phase 7 additions to those screens:
  - LevelCard: once `Progress.twist_open()`, a Twist part after the level's own: the Twist's name and text from the level file, whether it is cleared (a check mark and words), its own Normal or Relaxed choice with Normal preselected, and a button to play it. A saved game of the Twist offers Resume in that part, and a saved game of the level itself in the level's part.
  - Playing a Twist: the battle gets the level's `twist_effects` (step 3) and is saved with `twist` true. On every fresh start (tick 0, no wave started) the Twist's rule is the first hint, "Twist: " and its text, in place of the level's own hint and highlight. Closing it marks nothing seen, so the next fresh start shows it again. A Twist has no stars and no star warnings. A Twist win, on Normal or Relaxed, records the Twist (`Progress.record_twist`) and no stars (RULES 13). The Continue card says "Level 1-2 Twist" where a level says "Level 1-2".
  - PausePanel: in a campaign level that is not a Twist, the three star lines with Earned, Not yet or Lost (2.7). In a Twist, the Twist's name and text in their place. A run or daily shows neither.
  - EndPanel, for a campaign level or Twist: a Twist (`result["twist"]`) says "Twist cleared" or "Twist lost", with no stars and no next level. After a Normal loss of a campaign level that is not a Twist, one more line: "Stuck? Relaxed gives N lives and more gold.", with N worked out from rules.json (`start_lives * relaxed_lives_pct / 100`) (FUN_REVIEW_R1 item 9).
  - RunEndPanel, for a run or daily that was won or lost: "Run won", "Run lost", "Daily won" or "Daily lost", the waves cleared of 18 and the lives left (RULES 14.7). A daily also shows its day, the day's best and the shown streak, as they stand after this run is recorded. After a Normal loss of a normal run, EndPanel's Relaxed line. Then Try again (Play again after a win) and Menu.
  - RunCard: before a normal run, what a run is, then Normal or Relaxed with Normal preselected and the lives and gold each gives (from the sim), then Start. Before the daily: the day, its best result so far and the shown streak, then Start (always Normal). With a saved game of that mode, Resume comes first and Start says "Start over". When the phone's date is not a day key, the daily card says "Check the phone's date." and has no Start, though Resume still shows for a saved daily. The card reads no clock and no file: the App passes the day, the best and the streak in.
  - DraftPanel: opens by itself whenever `run.draft_open()`, in portrait as a sheet like the build panel and in landscape in the side column, so the map stays readable. It shows each offer's kind in words, name and text, with the tower's silhouette for tower and perk cards and a glyph for the other kinds (`Silhouettes.draw_glyph`: gate, coin for economy, moon for risk). A pick takes a tap on a card, then Take. It cannot be skipped, and the next draft owed opens after it. While it is open, taps on the map and gate drags do nothing, and no other battle panel opens. The back button never closes it: back opens Pause, as in a battle with no panel open.
  - WavePreview: in a run, the waiting risk card (`run.risk_card()`) shows first, as a row at the top of the open preview with its name and text, and as a chip at the start of the strip (RULES 9.1).
  - InfoScreen: every tower, creature and boss from the data, and the rules of Twists, runs, cards and the daily (RULES 13 to 15).

App flow:

1. **Launch.** `GameData.load_from()`. If it has problems, show the damaged message and stop. Load settings, progress and the saved games (an invalid one is deleted), and the daily record (U3). Create the AudioService (3.8). Apply `UiTheme.build()`. Show the front door. Set `get_tree().quit_on_go_back = false`.
2. **Play** opens ModeScreen. When any game is saved, the Continue card on top resumes the most recent one in one tap. A saved game also resumes from its own way in: the Roguelite or Daily button, or the saved level's card. Playing a different campaign level or Twist while one is saved asks first; a level and its own Twist count as different, since `SavedGame` has a `twist` flag. If the player confirms, the saved game ends as if abandoned from Pause, and nothing is recorded (RULES 4.10). Roguelite and Daily stay locked until `runs_open()`. Until U3 (section 13) sets `App.RUNS_BUILT` true, the Roguelite and Daily cards are locked with "Coming in a later update." whatever the stars, and tapping them does nothing. Until then the App also starts no run or daily, loads no daily record and resumes no saved run or daily, though `SaveStore.load_games()` loads and checks them.
3. **Battle.** A campaign level: `Battle.create(level, catalog, relaxed, effects)`, where `effects` is the level's `twist_effects` when playing its Twist and empty otherwise. A normal run (phase 7): the App draws the seed (3.4), then `RunSession.start(seed, "", relaxed, game.run.pool(progress.unlock_counters()), game.run, game.catalog)`. The daily: `RunSession.start(RunSeeds.daily_seed(today), today, false, game.run.card_ids(), game.run, game.catalog)`, where `today` is `RunSeeds.day_key(Time.get_date_dict_from_system())`. Then `BattleScreen.setup()`, and for a run or daily `set_run()`, after which every call of the next wave goes through `run.start_next_wave()`. Every battle starts at 1x, a resumed one too (Bart, hard stop B). A resumed game opens paused, on the Pause menu.
4. **Saving.** On `save_requested` the App saves that mode's game. A new level is also saved as soon as its battle opens. On `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_WM_CLOSE_REQUEST` while a battle is open, it calls `battle_screen.pause()` if a wave is running, then saves. Settings and progress save when they change.
5. **End.** On `ended` the App deletes that mode's saved game, then records and saves. A won campaign level records its stars (`Progress.record_level`). A won Twist, on Normal or Relaxed, records the Twist (`Progress.record_twist`) and no stars. A run or daily records the counters, and a daily the daily record (U3). Then EndPanel shows for a campaign level or Twist, and RunEndPanel for a run or daily (U3). An abandoned game shows no end panel: the App goes back to the front door. An abandoned campaign level or Twist records nothing. An abandoned run or daily counts as lost at its current wave (RULES 14.7). For a run or daily, from `run.result()` (RULES 14.6): `raise(&"best_run_wave", reached)`; on a win `bump(&"runs_won", 1)`, also `bump(&"runs_won_normal", 1)` when not Relaxed, and `bump(&"risky_wins", 1)` when `risks` is 3 or more; for a daily, won, lost or abandoned, `bump(&"dailies_finished", 1)` and `DailyRecord.record_finish(run.day, result)` with `won`, `waves` and `lives` from `run.result()`.
6. **Back button.** One press does exactly one step. `handle_back()`: close or answer the top modal first (a first sight card closes whole and counts as read), then go back one screen. A page opened from a modal, such as About from Settings, goes back before that modal closes. In a battle, an open build, tower or creature panel closes first, and the next press opens Pause. In the short wait between a battle's end and its end panel, a press shows the panel at once. On the front door or the damaged message, quit; everything is already saved. `handle_back()` returns `&"modal"` for a closed modal, a closed battle panel, Pause opening, or the end panel shown at once. A back press from the go-back notification and one from `ui_cancel` go through one entry that ignores a second press within 150 ms.
7. **Resize.** The App connects its viewport's `size_changed` and calls `apply_layout(window, safe)` with `Layout.safe_rect()`, which lays out every screen and modal (7.5).
8. **Debug builds** (`OS.is_debug_build()`) add a `PerfProbe` (3.7) that watches the open battle and its map view through `watch()`. BattleScreen times each `battle.step()` with `Time.get_ticks_usec()` and passes it to `record_tick_usec()` (9.2). Release builds do none of this.

First sight (RULES 9.2, 9.6): a tower's card opens at the start of the first level that offers it, a creature's card in the build phase before the first wave that brings it, and also, with the wave paused, when a creature of a kind the player has not seen first appears on the map (a wave called early, a released creature). A level's hint shows at its first start and closes when the player taps it or the first wave starts. In a Twist the Twist's rule takes its place (Playing a Twist, above). A tower or creature goes into `Progress.seen` only when the player closes its card, and a level when its hint closes. A creature keeps its "New" tag in the preview until the wave that brings it starts. In a run (phase 7), a tower's card opens after the player picks the tower card that adds it, if the tower is not in `Progress.seen`.

### 3.7 Render: src/render/, shaders/ (render-engineer)

```gdscript
class_name MapView extends Node2D                      # src/render/map_view.gd
const CELL: float = 128.0                              # local px per cell; fit() scales the node
func setup(battle: Battle) -> void                     # builds the static map layer and the entity pools
func fit(rect: Rect2) -> void                          # rect in the parent's coordinates; position and scale so the map fills it
func cell_at(global_point: Vector2) -> Vector2i        # a global canvas position to a cell; (-1, -1) outside the map
func enemy_at(global_point: Vector2) -> int            # the nearest creature within reach of a finger; -1 for none
func sync(alpha: float) -> void                        # every frame: adds, moves and frees entity nodes from battle state
func play_events(events: Array[Dictionary]) -> void    # projectiles, puffs, sparkles, gate effects; phase 7 adds heals,
                                                       # gate breaks and a small coin glint on each `defeated` with gold
func show_routes(routes: Array[Dictionary]) -> void    # Battle.routes() entries; [] hides the lines
func show_refused(cell: Vector2i) -> void              # the crossed out gate on that socket for 1.5 s (RULES 7.4)
func show_range(cell: Vector2i, reach: int, boost: bool) -> void   # reach in hundredths of a tile; boost: a Bakery's reach and the towers it would boost; (-1, -1) hides it
func show_selection(cell: Vector2i) -> void            # (-1, -1) hides it
func show_hint(cell: Vector2i) -> void                 # (-1, -1) hides it

class_name PerfProbe extends Node                      # src/render/perf_probe.gd: debug builds only (section 9)
func watch(battle: Battle, view: MapView = null) -> void   # what it reports on
func record_tick_usec(usec: int) -> void               # how long one Battle.step() took, from BattleScreen
```

- MapView draws in its own local space, where a cell is `CELL` pixels, with `MapArt` and `Silhouettes` (3.9). `fit()` changes only the node's position and scale, so a fold re-fits one transform and every child, particles in flight included, keeps its place.
- Towers and creatures draw in row order, lower on the screen in front, because a tower reaches up to 0.85 of a cell above its center. Creatures are drawn facing right; MapView flips a creature's node to face left. `frame` steps a 4 frame walk or flap cycle.
- Gate looks (phase 7). A placed gate takes the first look that applies: `BROKEN` while it is broken, until it mends (RULES 9.7; a locked gate can break too, RULES 14.6); `OPEN` while `battle.gates_open` is true, even when the gate is fixed, because it blocks nothing then (4.2, `closed_cells()`); `FIXED` for a Twist's `fixed_gates` or a gate locked by `gates_stay`; else `CLOSED`. So OPEN wins over FIXED (DM, 2026-10-24). An empty socket is `SOCKET`, and a refused drop shows `REFUSED` (`show_refused()`).
- `MapAtlas.add_gates()` (src/render/map_atlas.gd) bakes every look: it loops over `MapArt.Gate.size()`, never a fixed count.

### 3.8 Audio: src/audio/ (audio-engineer)

```gdscript
class_name AudioService extends Node                   # src/audio/audio_service.gd
func set_enabled(on: bool) -> void
func play_events(events: Array[Dictionary]) -> void    # battle events to sounds, with caps (section 9)
func play_ui(sound: StringName) -> void                # &"tap", &"refuse" (RULES 7.4) or &"star"
func set_music(track: StringName) -> void              # &"menu", &"battle", or &"" for silence
```

- The App creates the service with `AudioService.new()`, adds it as its own child (no autoload), and calls `set_enabled(settings.sound_on)` once at boot, then again whenever the setting changes. It passes the service down with `setup()`.
- AudioService makes its Sfx and Music buses at run time, so project.godot and the bus layout need nothing.
- A shot's sound comes from the `fired` event's `tower` and `spec` (3.1).

### 3.9 Theme: src/theme/ (art-director)

The art director built this. Each file's doc comments give the details. Other areas use only the members below; `InkPen` and `MapArt.gate_into()` are internal to src/theme/ and its tests. Everything takes ids from 2.2 and draws onto any `CanvasItem`, so src/theme/ uses nothing outside Godot's core types.

```gdscript
class_name Palette extends RefCounted                  # src/theme/palette.gd: the color tokens of docs/art/THEME.md, as constants

class_name UiTheme extends RefCounted                  # src/theme/ui_theme.gd
const FONT_SMALL: int = 40                             # sizes in logical px; FONT_BODY 46, FONT_BUTTON 52, FONT_TITLE 76, FONT_HUGE 112
const WEIGHT_REGULAR: int = 450                        # WEIGHT_BOLD 650, WEIGHT_HEAVY 800
static func build() -> Theme                           # every screen's Theme, Outfit throughout
static func font(weight: int = WEIGHT_REGULAR) -> FontVariation   # Outfit at 100 to 900, shared; for text drawn outside a Control
## Type variations: Button, PrimaryButton, CardButton, QuietButton; PanelContainer, Panel, CardPanel;
## Label, TitleLabel, SoftLabel, CardLabel, CardMutedLabel. Labels never sit straight on the map.

class_name Silhouettes extends RefCounted              # src/theme/silhouettes.gd: every tower and creature
const TOWERS: Array[StringName]                        # also SPECS (tower id to its 2 path ids), CREATURES, BOSSES, FLYERS
const TOWER_GROUND: float = 0.30                       # a tower's ground line: center.y + 0.30 * size
const FEET: float = 0.36                               # a walker's feet: center.y + 0.36 * size
static func draw_tower(canvas: CanvasItem, type: StringName, tier: int, spec: int, center: Vector2, size: float, flat: Color = NO_FLAT) -> void   # center: the cell center; size: the cell side
static func draw_enemy(canvas: CanvasItem, type: StringName, center: Vector2, size: float, frame: int, flat: Color = NO_FLAT) -> void   # size from enemy_size(); faces right
static func enemy_size(type: StringName, cell: float) -> float
static func has_tower(type: StringName) -> bool        # also has_enemy(type) and is_flyer(type)
static func draw_bubble(canvas: CanvasItem, center: Vector2, size: float) -> void
static func draw_drowsy(canvas: CanvasItem, center: Vector2, size: float, frame: int) -> void
static func draw_boost(canvas: CanvasItem, center: Vector2, size: float) -> void
static func draw_glyph(canvas: CanvasItem, glyph: StringName, center: Vector2, size: float, flat: Color = NO_FLAT) -> void   # &"heart", &"coin", &"moon", &"star", &"gate"

class_name MapArt extends RefCounted                   # src/theme/map_art.gd: the map, in map local pixels
enum Gate { SOCKET, CLOSED, FIXED, BROKEN, REFUSED, OPEN }   # OPEN (phase 7): a placed gate standing open under gates_open;
                                                       # it comes last, so the older looks keep their numbers
enum Route { WALK, BREAK, FLY }
static func draw_ground(canvas: CanvasItem, grid: PackedStringArray, cell: float, font: Font = null) -> void   # all that never moves; grid is LevelData.grid
static func draw_spot(canvas: CanvasItem, center: Vector2, cell: float) -> void
static func draw_base(canvas: CanvasItem, center: Vector2, cell: float) -> void
static func draw_highlight(canvas: CanvasItem, at: Vector2i, cell: float, pulse: float = 1.0) -> void
static func draw_gate(canvas: CanvasItem, grid: PackedStringArray, at: Vector2i, cell: float, look: Gate) -> void
static func draw_gate_at(canvas: CanvasItem, center: Vector2, cell: float, across: bool, look: Gate, flat: Color = ...) -> void   # across: the road runs up and down
static func draw_route(canvas: CanvasItem, points: PackedVector2Array, cell: float, style: Route, phase: float = 0.0) -> void
static func route_points(cells: Array[Vector2i], cell: float) -> PackedVector2Array   # through cell centers with the roads' round turns
static func road_runs_vertically(grid: PackedStringArray, at: Vector2i) -> bool

class_name Wordmark extends Control                    # src/theme/wordmark.gd; static draw_into(canvas, rect) for store art

class_name IconArt extends RefCounted                  # src/theme/icon_art.gd: the launcher and store icon
enum Layer { FULL, FOREGROUND, BACKGROUND, MONOCHROME }
static func draw(size: int) -> Image                   # await it; needs a rendering display, not --headless
static func draw_layer(size: int, layer: Layer) -> Image   # await it; straight alpha
static func paint(canvas: CanvasItem, rect: Rect2, layer: Layer) -> void
```

- Map cell (column, row) covers `[column * cell, (column + 1) * cell]` by `[row * cell, (row + 1) * cell]`.
- A tower stays within 0.52 of a cell left and right of its center and reaches up to 0.85 of a cell above it. An entrance's thicket reaches about 0.6 of a cell outside the map edge; its letter sign stays inside the map. The UI either leaves that room outside the map or lets the HUD or the screen edge cover part of the thicket. Nothing a player needs is drawn out there.
- `Silhouettes.FLYERS` must match the `flying` field of enemies.json, and every tower, path and creature id in data/stats/ must have a silhouette, specs in the same order. tests/theme/ checks both.
- The font is src/theme/fonts/Outfit[wght].ttf with its OFL.txt beside it, both unmodified (Bart, hard stop A). Only src/theme/ preloads the font. Everyone else uses the Theme or `UiTheme.font()`.

## 4. Routing (RULES 7)

### 4.1 The road graph

Nodes are road cells (`#`, `G`, `1` to `4`, `B`). Edges join orthogonal neighbors, and every edge is one step. `RoadMap` builds this once per battle.

### 4.2 Gates

- A closed gate closes its socket to walkers. Flyers ignore roads and gates (RULES 6.5).
- Gates in hand: the level's `gates` (or a Twist's `set_gates`), minus fixed gates, plus `add_gates` cards, minus the gates placed. A run never holds more than `max_gates` in all.
- Gate commands work only in BUILD (RULES 7.6). A move is one step: the gate leaves its socket and closes the new one at the same moment, and the seal check looks at the result (RULES 7.2).
- A broken gate is open to every walker until the next build phase begins. Then it mends, closed, on the same socket. Under `gates_open` every gate is open and cannot be broken until the next build phase.
- `closed_cells()` is the placed gates that are neither broken nor opened by `gates_open`.

### 4.3 The shortest open route and the tie break

- `RoadMap.distances(closed)` runs one breadth first search from the base over open road cells. The result is the number of steps to the base for each cell, or -1 when cut off.
- A walker at a cell center steps to an open neighbor whose distance is exactly one less. When several qualify, it takes the first in this fixed order: **south, west, east, north** (row + 1, column - 1, column + 1, row - 1). These are grid directions, the same in both layouts (RULES 7.3).
- A walker decides only at cell centers. Its first step is from its entrance's center.
- Distances are worked out again only when the closed set changes: a gate command in BUILD, a gate breaking, or `gates_open` starting or ending. One search covers at most 91 cells.
- When distances change during a wave, every walker except breakers uses the new distances from its next cell center, even if that turns it back (RULES 7.8).

### 4.4 The seal check

- A closed set seals when any entrance has distance -1. `place_gate` and `move_gate` refuse such a set with `&"would_seal"` and change nothing (RULES 7.4).
- In BUILD no creature is on the map, and gates never close during a wave, so checking the entrances is enough.
- A saved battle is refused when its placed gates seal, in a build phase or a wave, counting broken gates and gates opened by `gates_open`: they all close again when the next build phase begins (5.6). In play every placed gate came from a build phase, where placing or moving a gate never seals, so play never fails this.
- Level files and assembled run maps must have an open route from every entrance with no gates, and with only the fixed gates closed (2.3).

### 4.5 Gate breakers (RULES 7.7)

- A creature with `break_ms` walks the breaker route: the shortest route with no gates at all, with the same tie break. `RoadMap.distances([])` gives it, once per battle. Breakers never use any other distances.
- When the next cell on its route holds a closed gate, it stops at the center of the cell before the gate and breaks that gate: `break_ms` of breaking, slowed by its slow (3.1). Then it walks on, and it breaks every closed gate on its route in turn.
- Defeated while breaking: the gate stays closed and the breaking is lost. Each breaker keeps its own timer, and the first to finish breaks the gate. When another breaker breaks it first, it walks on.

### 4.6 Flyers

A flyer flies straight from its entrance's cell center, or from the spot where its release began (RULES 6.5), to the base's cell center. Its line length comes from `Sim.isqrt` once at spawn. Its position is `fly_from + (fly_to - fly_from) * flown / fly_length`, in integers.

### 4.7 Distance to the base, for targeting

- A walker: `dist[to_cell] * UNIT + (UNIT - progress)`, on the distances it walks (the breaker route for a breaker).
- A flyer: `fly_length - flown`.

First picks the smallest, Last the largest, and Strong the highest max health with ties by First. Any other tie goes to the lower id (RULES 8.2).

### 4.8 Route lines (RULES 7.5)

`Battle.routes(closed)` returns one entry per entrance, in entrance order:

```
{"entrance": int,              # 1 based
 "walk": Array[Vector2i],      # the walker route from the entrance to the base; empty when sealed
 "break": Array[Vector2i],     # the breaker route when the next wave has a breaker from this entrance; else empty
 "cracks": Array[Vector2i],    # the closed gates on the breaker route
 "fly": bool}                  # the next wave has flyers from this entrance
```

- "The next wave" includes the Twist and a waiting risk card. With `gates_open` waiting, the lines show every gate open: `walk` ignores the gates and `cracks` is empty (RULES 14.5).
- The lines show during every build phase and hide during waves. The UI shows `routes(closed_cells())`. While a gate is dragged over a socket, it shows `routes()` for the would-be closed set; over a socket where `seals()` is true, it calls `MapView.show_refused()` instead.
- The render draws `walk` solid, `break` dashed with a crack on each gate in `cracks`, and `fly` as a dotted straight line from the entrance to the base (`MapArt.Route`).

## 5. Save format

### 5.1 Files

All in `user://` (the app's private storage, removed on uninstall). Each may have a `.tmp` and a `.bak` beside it.

| File | Holds | Written | Size cap |
|---|---|---|---|
| settings.json | sound on or off | when it changes | 4 KB |
| progress.json | star bits per level, Twists won, seen ids, counters | when any of it changes | 64 KB |
| game_level.json, game_run.json, game_daily.json | one saved game per mode (Bart, hard stop A), at the exact moment | when a new level opens, when a build phase begins, after a card pick, when the HUD pause button pauses the game, when Pause opens, on focus loss, app pause and close request, and when leaving the battle. Deleted when that game ends. | 1 MB each |
| daily.json (phase 7) | the day's best daily result and the streak | when a daily ends | 4 KB |

Writes are synchronous on the main thread. The largest file is under 100 KB in the biggest wave, a few milliseconds to write. A write whose text equals the last text written to that file is skipped.

### 5.2 Reading

1. A missing file means defaults, or no saved game.
2. A file is **locked** when any of its three copies (`<name>.tmp`, `<name>`, `<name>.bak`) exists but cannot be opened. Its defaults are used in memory, and nothing in this launch writes, renames or deletes any of the three, because they may hold good data (5.4).
3. A file over its cap is refused before any of it is read.
4. A NUL byte or any byte of 0x80 or above is refused before parsing. Every saved string is an id, a day key, a mode or a number in a string, so the files are plain ASCII.
5. The text goes through `JSON.new().parse()`. A parse error means invalid. Godot's parser refuses nesting past its limit cleanly (checked with 4.7.2: 600 levels parse, 2,000 fail with an error, nothing crashes). Never `str_to_var`, `bytes_to_var`, `FileAccess.get_var`, `ConfigFile`, `load()`, `ResourceLoader` or anything that can make objects from file data.
6. Then every field is checked for type, range and shape.
7. A file whose `format` is higher than this build knows is treated like a locked file, so a newer save is never overwritten by an older build. A saved game is the exception: it is deleted.

### 5.3 Writing (atomic)

1. Build the dictionary with `to_data()`: only bool, int, String, Array and Dictionary values. Vector2i becomes `[x, y]`, StringName becomes String, and an enum value becomes its lowercase name.
2. `JSON.stringify(data)` (sorted keys). Refuse to write text that is not plain ASCII.
3. Write the text to `<name>.tmp`, flush, close. Read it back and compare. On any difference, delete the `.tmp` and return false.
4. If `<name>` holds exactly the text this store last wrote or loaded as valid, rename it to `<name>.bak`. SaveStore passes that text to `JsonFile.write_atomic` as `backup_of`. With no such text, there is no backup step. If that rename fails, carry on without a fresh backup.
5. Rename `<name>.tmp` to `<name>`.
6. **A failed rename** returns false and leaves the `.tmp` in place. It holds the newest complete save, and the next load uses it. The next write tries again. On Windows, Godot's rename removes the target, then moves the file in: it fails while another program holds the target (checked with 4.7.2: the old file stays, the `.tmp` stays), and SumUp saw it fail half way while the temp file was held (the target gone, the `.tmp` kept). On Android, Godot uses POSIX rename, which replaces the file in one step. In every case a kill at any moment leaves a complete newest save in `.tmp` or `<name>`, plus the `.bak`.
7. The App logs a failed save once per launch, not every time. No error shows to the player.

### 5.4 Loading order

First every copy is probed. If any of `<name>.tmp`, `<name>` and `<name>.bak` exists but cannot be opened, the whole file is locked for the rest of this launch. Its defaults are used, or no saved game for a game file, and nothing writes, renames or deletes any of the three copies. A newer `format` in a copy of settings, progress or daily locks the file the same way (5.2). `SaveStore.is_locked()` reports it.

Then try a valid `<name>.tmp` first (it is always the newest attempt); if it is valid, rename it into place. Then a valid `<name>`. Then a valid `<name>.bak` (one save behind). A `.tmp` that fails its check is deleted. For settings, progress and daily, "valid" means a JSON object with a known `format`, and any bad field inside falls back to its own default. For a saved game, "valid" means every check in 5.6 passes. When no copy of a saved game passes, all three are deleted (`.tmp`, then `.bak`, then the file), so a bad save never comes back.

### 5.5 Shapes and ceilings

Ceilings are far above anything a real player reaches. Counters saturate at their ceiling, so the game never writes a value its own check refuses.

```json
{"format": 1, "sound": true}
```

```json
{"format": 1,
 "levels": {"r1_l1": 7, "r1_l2": 3},
 "twists": ["r1_l1"],
 "seen": ["sling_post", "pumpkin_catapult", "scamp", "r1_l1"],
 "counters": {"best_run_wave": 9, "runs_won": 1, "runs_won_normal": 0, "dailies_finished": 2, "risky_wins": 0}}
```

- `levels`: at most 512 entries, keys in id form, values 0 to 7. Unknown but well formed ids are kept, so a later version's progress survives, and `stars()` counts them too. Only an edited file or a downgrade can add them, and the 512 entry cap holds the total to 1,536 stars.
- `twists`, `seen`: at most 512 ids each, no repeats.
- `counters`: the five names of RULES 14.6, each 0 to 1,000,000,000. A missing one is 0, and an unknown one is dropped.

```json
{"format": 1, "mode": "run", "order": 41, "level_id": "", "twist": false,
 "battle": {},
 "run": {}}
```

- `mode` is `level`, `run` or `daily` and matches the file name. `order` is 0 to 10^12. `level_id` is a campaign level id for `level` and `""` otherwise. `battle` holds `Battle.to_data()` (5.6). `run` is null for `level`, and `RunSession.to_data()` for `run` and `daily`.

```json
{"format": 1, "seed": 3141592653, "day": "", "pool": ["tower_bakery", "sharp_pebbles", "spare_gate", "gold_purse"], "picks": ["sharp_pebbles"]}
```

- `RunSession.to_data()` (phase 7): the seed, the day (`""` for a normal run), the pool fixed at the start and the picks in order. Everything else (owed drafts, offers, the run's towers, the risk count) is worked out again from these and the battle.

```json
{"format": 1, "day": "2026-10-23", "best": {"won": false, "waves": 12, "lives": 0},
 "streak": 3, "streak_day": "2026-10-23"}
```

- daily.json (phase 7): `day` and `streak_day` are `""` or a real calendar date from 2026-01-01 to 2200-12-31. `best` is `{}` or the result shape with numbers 0 to 1,000. A `day` with no valid `best`, or a `best` with no valid `day`, loads as neither. `streak` is 0 to 100,000. DailyRecord keeps every number as an int, loaded or recorded, because `Daily.is_better` counts a number of any other type as 0.

### 5.6 The saved battle

`Battle.to_data()` and `Battle.from_data()` belong to the sim-engineer, and the shape inside is internal to src/sim/. The rules:

- It holds the level (`LevelData.to_data()`), so an assembled run map or a later data change never breaks a saved game. It also holds `relaxed`, the Twist's effects (`twist`), the kept card effects (`effects`), the waiting risk card (`risk`), and every field that affects a later tick: the tick, the phase, the waves started and running, the tick each started wave began, the risk card each running wave took (`wave_risk`), whether gates stand open (`gates_open`), gold, lives, the gates and how many gates cards added (`gates_added`), towers with their purchases, creatures with every timer, `heal_at` (the tick of the next heal) among them, plus `ups` (the speed ups taken) and `released` (whether the health release has begun), queued releases (`Battle.Release`), the next id, and what the star rules need.
- Rebuilt on load, not saved: positions between ticks, the distance fields, the folded effects, the spawn counters (worked out from each wave's start tick), and each creature's armor, speed, lives and bounty (worked out again from its type, its speed ups, its wave's strength and the effects).
- `from_data` checks everything, all or nothing:

| Field | Rule |
|---|---|
| level | passes `LevelData.check` |
| twist | at most 8 effects, passing `Modifiers.check` for `twist`; fixed gates on sockets of the level |
| effects | at most 64 kept card effects, passing `Modifiers.check` for `card`, none of them instant |
| risk | the waiting risk card: at most 8 effects, passing `Modifiers.check` for `risk`, every `add_group` entrance on the map |
| wave_risk | at most one entry per running wave, in start order: the risk card that wave took, 1 to 8 effects checked the same way as `risk` |
| wave effects | each wave with the Twist and its risk card (its `wave_risk` entry while it runs, the waiting risk for the next wave to start, none otherwise): no group of its own above 4,000 (`MAX_ENEMIES`), added groups keeping their card's count; `speed_pct` effects together at most 1,000 percent (`MAX_SPEED_PCT`); and the catalog's largest health at the wave's strength, with its `health_pct` effects, at most 1,000,000,000, so every creature the wave can bring has a max health a save may hold |
| kept effect ceilings | with the kept card effects: every number of every stat block of every tower in the catalog (`cost` as a build and as an upgrade price, `reach`, `damage`, `reload_ms`, `splash`, `targets`, `boost_pct`, `boost_damage`) at most 1,000,000 (`MAX_TOWER_STAT`); and in every wave, the catalog's largest bounty and the clear bonus, at the wave's strength, at most 1,000,000 (`MAX_GAIN`) |
| tick | 0 to 1,000,000,000 |
| phase | `build` or `wave` |
| waves | waves started 0 to the level's wave count; running waves in start order, at most `max_waves_running`; each start tick 0 to `tick` and not before the one before it |
| gold | 0 to 1,000,000,000. Play holds gold at most 1,000,000,000, so a save made in play always passes. |
| lives | 1 to 1,000,000, and `start_lives` the same. Lives may be above `start_lives` (a game saved before the cap of 2.8): load keeps them. |
| gates | each on a socket, at most one per socket; `gates_added` 0 to `max_gates`; placed and in hand add up to the gates given (the level's, or the Twist's `set_gates`) plus `gates_added`, at most `max_gates` in all; every fixed cell of the Twist holds a fixed gate, and any other gate is fixed only under `gates_stay`; a gate is broken only in `wave`; the placed gates do not seal, in `build` and in `wave`, counting every placed gate, broken or not, whatever `gates_open` says |
| gates_open | false in `build` |
| towers | at most the spot count; each on its own spot; a tower the battle offers (the level's, plus `add_tower`, less `ban_tower`); tier 1 to 3; spec matching the tier and inside any cap; a reload timer from 0 to its `reload_ms * 100`, with card effects (3.1) |
| creatures | at most 4,000; ids 0 to 2^31, unique and below the next id; known types; each of a running wave; health 1 to max health, max health 1 to 1,000,000,000; walkers on joined road cells with progress 0 to UNIT; flyers inside the map; every timer inside its data range, `heal_at` included; `ups` at most the creature's number of speed up steps; `released` true only for a creature with a health release; creatures that summon and that heal: see "at once" |
| releases | at most 1,000; each a known creature of a running wave, 1 to 200 still to come, the next one due within one gap, starting as a creature would (walkers on joined road cells, flyers inside the map); live creatures plus every creature still to come from releases, each counted with what it can still let out (1 plus its `split_count`; plus its release `count` while a health release has not begun), at most 4,000 (`MAX_ENEMIES`) |
| at once | Per wave, a tally of creatures that summon and a tally of creatures that heal: its live creatures, its creatures still to come from releases, and what its groups have not yet spawned at the saved tick (with the Twist and the wave's risk card). A wave not started holds all of its groups (the next wave with the waiting risk card). Each creature counts with what it can let out; summons are not counted. For each kind, the sum of the `max_waves_running` largest tallies is at most 8 that summon (`MAX_SUMMONERS`) and at most 40 that heal (`MAX_HEALERS`). |
| every number | whole, finite and in range, then converted to int |

`RunSession.from_data` (phase 7) checks the run the same way, all or nothing: exact keys and `format` 1; a seed from 0 to 2^32 - 1; `day` either `""` or a day key whose `daily_seed()` is the seed, and then a battle that is not Relaxed; a pool of 1 to 256 known card ids with no repeats, holding at least one economy card that is not `once` (3.4); picks of 0 to 17 card ids from the pool, a `once` card at most once, and no more picks than the battle has cleared waves among waves 1 to 17. The battle's card effects must come from the picks. `RunSession.from_data` rebuilds the kept card effects from the picks, in pick order, from the card data (`Modifiers.normalize_all` of each non-risk card's effects, less the instant types), and refuses a run whose battle's `effects` differ in any key, value or order. A waiting risk card (`risk`) must be the effects of the last risk card picked, and the battle must be in `build` with fewer than 17 waves started. Each `wave_risk` entry must equal the effects of an earlier risk pick, matched in pick order, each pick used at most once, and never the pick still waiting. A save that breaks any of this is refused the same way as any other bad run. A saved campaign level is still matched to the bundled level only by its id. `SavedGame.from_data` checks that a campaign level's battle holds that level's Twist effects when `twist` is true and none otherwise, with no kept card effects, no waiting risk card, no `wave_risk` entry, `gates_added` 0 and `gates_open` false, because only cards and risk cards give those; that a run or daily battle holds no Twist; and that a daily battle is not Relaxed. It also checks that a campaign level's `run` is null, and that a run or daily has a `run` object. `RunSession.from_data` checks that object around the battle saved with it. Mode `daily` needs a day and mode `run` needs none, so neither can pass as the other. With no run data (`game.run` null), every saved run and daily is refused.

## 6. Resume after the app is killed (brief 3.10)

Bart chose the exact moment (hard stop A).

- Leaving the app always saves: focus loss and app pause come first, even when the app is later swiped away or killed in the background (3.6, step 4).
- The saved game holds the whole battle: creatures, timers, towers, gates, gold, lives and effects (5.6). Killing the app undoes nothing, so it cannot dodge a run loss or retry a daily.
- On launch the App loads every saved game. The Continue card resumes the most recent one; each mode's own way in resumes that mode's game (3.6, step 2). A resumed game opens paused, on the Pause menu.
- tests/sim/ proves it: snapshot at many ticks on levels with every creature, tower and effect, restore, play on, and compare with an uninterrupted run (section 10).

## 7. Orientation and layout (brief section 5)

### 7.1 What Android does now (researched 2026-10-23)

- **Android 16 (API 36).** For apps targeting API 36, on displays whose smallest width is 600 dp or more, Android ignores `screenOrientation`, `resizeableActivity`, `minAspectRatio`, `maxAspectRatio`, `setRequestedOrientation()` and `getRequestedOrientation()`. Apps fill the display. Exceptions: games, identified by `android:appCategory`; screens below sw600dp; and users who pick the app's default in the aspect ratio settings. A temporary opt-out, `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`, works only while targeting API 36. [1] [3]
- **Android 17 (API 37)** removes that opt-out. The game exception stays. Google Play will require API 37 for new apps and updates in August 2027. [2] [4]
- **Google Play** requires API 36 for new apps and updates since August 31, 2026. [5]
- **Configuration changes.** Rotation, fold, unfold and resizing recreate an activity unless it declares them in `android:configChanges`. Google's guide for games says to declare `orientation`, `screenSize`, `smallestScreenSize`, `screenLayout` and `density`, and to be resizable. On some devices an app that cannot handle a move between screens is offered a restart. [3] [6]
- **`android:appCategory`** takes `game` among other values. `android:isGame` is deprecated in its favor. [7]
- **Bart's Fold5** received One UI 8 (Android 16) in late 2025 and One UI 8.5 (Android 16 QPR2) from May 2026. [8] [9] Its screens: cover 904 x 2316 px, inner 1812 x 2176 px. [10] SumUp measured both at density 2.625 on this phone: the cover is 344 x 882 dp (smallest width 344, a small screen) and the inner screen is 690 x 829 dp (smallest width 690, a large screen). The inner screen also showed a 48 dp taskbar inset at the bottom.

### 7.2 What Godot 4.7.2 exports

Checked in the Godot 4.7.2 source [11] [12] and in the installed release template with `aapt2 dump xmltree --file AndroidManifest.xml %APPDATA%\Godot\export_templates\4.7.2.stable\android_release.apk`:

- `targetSdkVersion` 36 and `minSdkVersion` 24 by default (`gradle_build/target_sdk` and `min_sdk` empty).
- `package/app_category` defaults to Game. The export writes `android:appCategory="game"` and `android:isGame="true"`.
- `display/window/handheld/orientation` becomes `android:screenOrientation`. Our value 1 is `portrait`.
- `display/window/size/resizable` becomes `android:resizeableActivity`. The project default is true.
- The game activity declares `configChanges` 0x3ff4: `orientation`, `screenSize`, `smallestScreenSize`, `screenLayout`, `density`, `uiMode`, `keyboard`, `keyboardHidden`, `navigation`, `locale`, `layoutDirection`. So rotation, fold and unfold resize the running game. The activity and the engine are not recreated. Only `fontScale` is missing: a change of the system font size recreates the activity, and the save brings the player back.
- `screen/immersive_mode` defaults to true, `screen/edge_to_edge` to false.

### 7.3 What this means for Forkline

- Forkline is a game, so on Android 16 and 17 its portrait lock is still honored on the Fold5's inner screen. Unfolded and held normally, that screen is 1812 x 2176, already close to square, and the game fills it. The game shows its landscape layout there because the window is close to square, not because the phone turned.
- Bart chose no rotation on the unfolded phone (hard stop A): the portrait lock stays on every screen, and the landscape layout comes only from the window shape.
- The lock is not a guarantee. Split screen, pop-up windows, the user's aspect ratio setting, and future Android or Samsung changes can hand the game any window shape. So the layout never reads the orientation. It reads the window size, on every change.
- Folding mid-wave is a window resize inside the same running game. Nothing is rebuilt.

### 7.4 The layout rule and the map size

`Layout.is_landscape(size)` is true when the window's height is less than 1.5 times its width. It is a pure function of the window size, checked on every resize. No setting. (The theme slice switched at a width to height ratio of 0.8. This rule replaces it.)

| Window | Height / width | Layout |
|---|---|---|
| Fold5 cover, 904 x 2316 | 2.56 | portrait |
| 20:9 phone, 1080 x 2400 | 2.22 | portrait |
| 16:9 phone, 1080 x 1920 | 1.78 | portrait |
| 16:10 tablet upright, 1600 x 2560 | 1.60 | portrait |
| 4:3 tablet upright, 1536 x 2048 | 1.33 | landscape |
| Fold5 inner, 1812 x 2176 | 1.20 | landscape |
| Fold5 inner turned, 2176 x 1812 | 0.83 | landscape |

Why 1.5: every phone shape stays portrait, and the Fold5 inner screen gets the landscape layout, which shows the bigger map there. With the 360 px portrait HUD, portrait would show a slightly bigger map on rarer windows such as an upright 4:3 tablet: between ratios of about 1.25 and 1.5 for 11 rows, and 1.4 and 1.5 for 13 rows.

The map never rotates. The same 7 column grid shows in both layouts; only the HUD moves (RULES 3.1).

- **Portrait:** the HUD above the map and nothing else in the layout flow. The HUD is two rows of 48 dp controls, 360 logical px with its margins. The first row holds the numbers, the gate chip and the pause button; the second the speeds and the call button. The map gets the rest of the safe area, as large as fits, aligned to the top. On the cover the width decides, so cells stay 154 px, 49 dp for any row count up to 13. The map never loses height to any state.
- **The gate chip** shows the gate picture and the number in hand, and a lock during a wave. Drag from it as from the landscape strip. A tap on it shows its sentence, "Drag one onto a marked road, or tap a marked road.", as a dock message (FUN_REVIEW_R1 item 6).
- **The call button** has the honey `PrimaryButton` look only as "Start wave N" in a build phase. An early call keeps the plain `Button` look with its "+N" and works the same (FUN_REVIEW_R1 item 3).
- **The dock** floats at the bottom of the safe area, under the map or over its lowest rows. Top to bottom it holds the messages (the HUD's and the gate chip's), the Paused strip and the wave preview. The dock and the floating hint hide while a build, tower, creature or draft sheet is open. Messages last 3 s. Besides refusals they include "Wave 3 cleared: +35 gold." when a wave is cleared, from the `wave_cleared` event (FUN_REVIEW_R1 item 8).
- **The wave preview** (settled 2026-10-24, section 12) is folded into its strip during waves. When a build phase begins, and whenever the layout changes, it opens only if its open form fits in the room under the map: its top, with the dock's 12 px bottom gap, stays at or below the map's lowest row. Otherwise it starts that build phase folded. A tap on the strip opens it over the map and a tap on its header folds it, and that choice holds until the next build phase or layout change. The open form: with 3 or more groups and no boss, small upright cells about 190 px tall, up to 4 across as the names fit; a boss wave, or a row the player opened, uses full rows.
- **The strip** is always one line: per group its picture, count and entrance letter, with the New tag, in spawn order. When the chips do not fit one line, it shows as many as fit and then a "+N" chip for the rest; the open preview lists them all. On the cover it is 206 px tall above its 12 px gap.
- **The hint** takes no height and closes on a tap or at the first wave. It goes to the first of these that works: (1) at the top of the dock, when the dock with the hint still stays at or below the map's lowest row; (2) over a band of whole map rows, wholly above the dock, that hold no build spot, gate socket, entrance, home, highlighted cell, fork or join (a road cell with three or four road neighbors), nearest the highlight, or nearest the top of the map when the highlight is the call button, or nearest the bottom when nothing is highlighted; (3) at the top of the dock (FUN_REVIEW_R1 item 5).
- **The call button highlight** (`hint.button` `"call"`, RULES 12.4, level 2-1; settled 2026-10-24): the call button wears the highlight, a pulsing ring around it (a shape, not only a color), whenever it offers an early call, until the player first calls a wave early on this battle screen. It never glows in a build phase, so it never points at "Start wave N". The hint itself shows at the level's first start, as on every level.
- **What stays in sight.** On the Fold5 cover in portrait, every build spot, gate socket, entrance, the home and any tower stay fully visible in the default build state, during waves and with the hint, on maps of 8 to 13 rows: the preview folds when it does not fit, the strip is one line, and a 13 row map keeps its bottom row scenery only (2.4, 2.9). The Paused strip and messages may cover more of the lower map, but never the highlighted cell. Measured on 2026-10-24 with the real battle screen at the test insets (96 px top, 171 px bottom): the room under the map is 443 px at 11 rows, 289 px at 12 and 134 px at 13; the open preview is 364 px for 1 or 2 groups, 388 px for 3 or 4 compact groups, 588 px for 5 or more, and 478 to 830 px for boss waves. Shorter screens, such as 20:9 and 16:9 phones, are height limited: the map fills its slot there, and the dock can cover part of the lowest rows. The Fold5 cover is the design target.
- **Landscape:** the map at full height inside the safe area, and one side panel at least 720 logical px wide for the HUD, the build panel, the draft panel and the wave preview. The preview is always open there in a build phase, and the hint sits in the side panel. The call button highlight and look are the same as in portrait.
- The project keeps its 1080 x 2400 base with `canvas_items` stretch and `expand`, so the cover screen is 1080 x 2767 logical px and the inner screen 1998 x 2400.
- An entrance thicket (3.9) that reaches past the map edge may sit under the HUD or the dock, or past the screen edge.

Touch size, with SumUp's measured densities and the same base viewport:

| Screen | Logical px per dp | 160 px (`MIN_TOUCH`) | Map cell, 7 columns |
|---|---|---|---|
| Fold5 cover | 3.14 | 51 dp | 154 px, 49 dp, in every state |
| 20:9 phone at 2.625 | 2.63 | 61 dp | height limited: 144 px, 55 dp at 13 rows |
| Fold5 inner, landscape | 2.89 | 55 dp | height limited: about 167 px, 58 dp |
| 16:9 phone at 2.625 | 3.28 | 49 dp | height limited: 144 px, 44 dp at 13 rows |

Bart approved 7 columns by 8 to 13 rows at hard stop A, so map cells stay at 48 dp on the Fold5 cover. The table assumes the 360 px portrait HUD and the measured insets: about 170 logical px on the cover and on phones, about 230 on the inner screen with its taskbar. Old 16:9 phones still fall short on tall maps: just under 48 dp at 12 rows and 44 dp at 13 (RULES 17). Taps on the map only select a cell or drag a gate; building, upgrading and selling happen on 48 dp buttons.

### 7.5 Folding and unfolding mid-wave

1. Android resizes the window. Godot keeps running (7.2).
2. The App gets `size_changed` and calls `apply_layout(window, safe)` on every screen, BattleScreen included.
3. If a wave is running and the game is not paused, BattleScreen's `apply_layout` first calls `pause()`. Bart chose this at hard stop A. Any size change during a wave pauses, so split screen and pop-up windows behave the same as a fold.
4. `apply_layout` picks the layout, moves the HUD parts into the portrait or landscape container and calls `map_view.fit(map_rect)`. It never frees a node that holds state and never touches the Battle. The selection, an open panel and the speed stay. A touch in progress (a gate drag, a held button) is cancelled.
5. If the fold comes with a focus loss (Samsung can ask whether to continue on the cover screen), the game also saves, as for any focus loss.
6. If Android ever recreates the activity anyway, the engine restarts and the exact moment save resumes the battle (section 6).

### 7.6 Settings for the DM and the release engineer

project.godot (DM):

- Keep `display/window/handheld/orientation=1` (portrait) on every screen.
- Keep `display/window/size/resizable` at its default, true. Never set it false: that would make the game non-resizable, and large screens may then show it in compatibility mode or offer a restart on fold.
- Keep the 1080 x 2400 base, `canvas_items` stretch and `expand`.
- Nothing else is needed for orientation. `application/run/max_fps` waits for the measurement in 9.4. Set `input_devices/pointing/emulate_touch_from_mouse=true` only if the ui-engineer asks for it to test map touches on Windows.

export_presets.cfg (release-engineer):

- `include_filter="LICENSE, NOTICE, data/*, src/theme/fonts/OFL.txt"`. LICENSE, NOTICE and the font license ship as plain files that About reads, and every data JSON ships.
- `exclude_filter="tools/*, tests/*, docs/*, prototypes/*, scripts/*"`.
- The font ships as Godot's imported font resource, which keeps the TTF's bytes unchanged, with OFL.txt beside it as a plain file. The raw .ttf is not added a second time (DM, 2026-10-23, recorded in CLAUDE.md, as in SumUp).
- Launcher icons from the art director's committed PNGs:
  - `launcher_icons/main_192x192="res://icons/icon_192.png"`
  - `launcher_icons/adaptive_foreground_432x432="res://icons/icon_foreground_432.png"`
  - `launcher_icons/adaptive_background_432x432="res://icons/icon_background_432.png"`
  - `launcher_icons/adaptive_monochrome_432x432="res://icons/icon_monochrome_432.png"`
- `package/app_category=2` (Game, the default).
- `screen/immersive_mode=true` and `screen/edge_to_edge=false` (the defaults). The UI uses the safe area. QA checks the cover screen's camera cutout and the inner screen's taskbar inset.
- `screen/support_small`, `support_normal`, `support_large` and `support_xlarge` all true.
- `gradle_build/target_sdk` and `min_sdk` empty (36 and 24).
- `user_data_backup/allow=false` and `package/retain_data_on_uninstall=false`. The app never sends saves anywhere, and they go with an uninstall. Cloud and adb backup are off, but some phones can still move app files in a device to device transfer [7] (security review N5).
- No permissions.
- The APK check (scripts/check_apk.sh) confirms: `targetSdkVersion` 36, `screenOrientation` 1, `resizeableActivity` true, `appCategory` game, `configChanges` including 0x1d80 (orientation, screenLayout, screenSize, smallestScreenSize, density), no `uses-permission`, `assets/LICENSE`, `assets/NOTICE` and `assets/src/theme/fonts/OFL.txt` inside, and every file under data/ inside.

### 7.7 Sources

1. Android 16 behavior changes: https://developer.android.com/about/versions/16/behavior-changes-16
2. Android 17, restrictions on orientation and resizability are ignored: https://developer.android.com/about/versions/17/changes/ff-restrictions-ignored
3. App orientation, aspect ratio and resizability: https://developer.android.com/develop/adaptive-apps/guides/app-orientation-aspect-ratio-resizability
4. Prepare your app for the resizability and orientation changes in Android 17 (2026-02-13): https://developer.android.com/blog/posts/prepare-your-app-for-the-resizability-and-orientation-changes-in-android-17
5. Google Play target API level requirements: https://developer.android.com/google/play/requirements/target-sdk
6. Support large screen resizability for games: https://developer.android.com/games/develop/multiplatform/support-large-screen-resizability
7. The application element, `appCategory`, `isGame` and `allowBackup` (checked again 2026-10-25): https://developer.android.com/guide/topics/manifest/application-element
8. Fold5 stable One UI 8: https://www.sammobile.com/news/galaxy-z-fold-5-flip-5-get-stable-one-ui-8-update/
9. Fold5 stable One UI 8.5: https://www.sammobile.com/news/galaxy-z-fold-5-flip-5-get-stable-one-ui-8-5-update
10. Samsung Galaxy Z Fold 5 screens: https://en.wikipedia.org/wiki/Samsung_Galaxy_Z_Fold_5
11. Godot 4.7.2 manifest code: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/android/export/gradle_export_util.cpp
12. Godot 4.7.2 export options and defaults: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/android/export/export_plugin.cpp and https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformandroid.html

## 8. Outbound links

```gdscript
class_name Links extends RefCounted                    # src/ui/links.gd (ui-engineer)
const COFFEE_URL: String = "https://buymeacoffee.com/playinc"
const SOURCE_URL: String = "https://github.com/bartbasi/forkline"
const SOURCE_SHOWN: String = "github.com/bartbasi/forkline"   # how About writes it
const FEEDBACK_EMAIL: String = "bartbasi@gmail.com"
## Who opens a link. Empty means the phone (OS.shell_open). Tests put a recorder here.
static var opener: Callable = Callable()
static func open(url: String) -> void                  # only when is_ours(url): the opener if set, else OS.shell_open; a failure shows nothing
static func is_ours(url: String) -> bool               # COFFEE_URL, SOURCE_URL, or exactly feedback_url(version(), device_text())
static func open_coffee() -> void                      # open(COFFEE_URL)
static func open_source() -> void                      # open(SOURCE_URL)
static func send_feedback() -> void                    # open(feedback_url(version(), device_text()))
static func version() -> String                        # ProjectSettings application/config/version
static func device_text() -> String                    # "%s, %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version_alias()]
static func feedback_url(version: String, device: String) -> String
```

- Each address is a constant written once. Nothing is ever added to the coffee or source address. The feedback address is a constant too; only the subject and body of the draft carry the version and device.
- `is_ours()` accepts the two web addresses and exactly the draft `feedback_url(version(), device_text())` builds, so a draft with anything added or changed is refused (security review N2, commit 279500b). `open()` refuses every address for which `is_ours()` is false, so no other address can ever leave the app, whoever calls it.
- `feedback_url` returns `"mailto:%s?subject=%s&body=%s" % [FEEDBACK_EMAIL, subject.uri_encode(), body.uri_encode()]`, with subject `"Forkline feedback (version %s)" % version` and body `"\n\n\nSent from Forkline %s on %s" % [version, device]`, so the player writes above that line. `uri_encode` turns `&`, `?`, `#`, `=` and line breaks into escapes, so a strange model name cannot add a recipient or a header. The player sees and can edit everything before sending; the app sends nothing.
- Phone model: `OS.get_model_name()` (Build.MODEL, for example SM-F946B). Android version: `OS.get_version_alias()`, which on Android gives the marketing version plus the SDK and build; `OS.get_version()` gives only the SDK number and build.
- The coffee tap rules (look, deadzone, one hand-off per tap, coming back) are the playbook's section 5, applied by the ui-engineer.
- Only src/ui/links.gd calls `OS.shell_open` (checked by tests/project/). Tests set `Links.opener` to a recorder in `before_each()` and reset it to `Callable()` in `after_each()`. A lambda left in a static var crashed Updraft's engine on quit.

## 9. Performance budget

Target: 60 fps on the Fold5 (Snapdragon 8 Gen 2), on both screens, through the largest wave of the game at 3x.

### 9.1 Entity ceilings

| Thing | Budget | Held by |
|---|---|---|
| Live creatures at once, Puffs and releases included | 200 | The planned peak. The spawn bound (2.4) holds one wave to 120 counting splits, and at most `max_waves_running` (2) waves run at once, so a failing defense can see more: up to 240 plus boss summons. The bots report the real peak. |
| Towers | 24 | Build spots per map (2.3) |
| Drawn projectiles in flight | 150 | The render pools them. The sim has no shots: hits land at once. |
| Particles alive | 400 | Pooled emitters, at most 24, at most 16 particles per puff |
| Sound voices | 12 | At most 3 of the same sound at once |
| Draw calls per frame | about 200 | Measured |

### 9.2 Time per frame on the Fold5 (16.7 ms)

- Sim: at most 2 ms per tick at the 99th percentile, at 3x with 200 live creatures. At 3x and 60 fps that is about one tick per frame.
- Render and UI scripts (`sync`, events, HUD): at most 3 ms.
- GPU: at most 8 ms.
- The 99th percentile frame over the whole wave: at most 20 ms.

These Fold5 numbers are the budget. The dev PC number is only an early warning.

- **Dev PC, headless.** tests/sim/test_battle_perf.gd times a crowd of 200 or more creatures. Its 0.5 ms per tick is a **mean**, not a worst case. The test fails only past a 2 ms mean, so a busy machine does not fail the suite. The 99th percentile is printed, not budgeted, because other programs on the PC move it. Three runs on 2026-10-23, peak 205 creatures: mean 0.35 to 0.51 ms, 99th percentile 0.9 to 1.1 ms.
- **The Fold5 decides, in phase 6.** The render engineer plays the largest region 1 wave at 3x on both screens and reads PerfProbe's wave summary (9.4):
  1. Mean frame at most 16.7 ms and 99th percentile frame at most 20 ms, on both screens: no more performance work, whatever the PC shows.
  2. Otherwise, if the sim's 99th percentile tick is over 2 ms: the sim engineer speeds up the sim before any more content.
  3. Otherwise: the render and UI scripts are sped up first.
- Phase 7 measures again with the largest wave of the game (brief section 11).

### 9.3 Draw approach

- The static map (`MapArt.draw_ground`) is drawn once into its own layer and redrawn only on a resize of the cell size. Gates, route lines and highlights draw on their own small layers.
- One Node2D per tower and per creature, drawn with `Silhouettes` and redrawn only when its look or animation frame changes. Each frame only its position changes. Nodes are pooled and reused.
- Health bars for hurt creatures and all projectiles are drawn by one overlay node each, redrawn every frame.
- Sparkle puffs use pooled one-shot `CPUParticles2D` emitters (simulated in C++, predictable in the Compatibility renderer).
- No `Light2D`, no screen-reading shaders (`SCREEN_TEXTURE`, `BackBufferCopy`), no full-screen transparent layers beyond one sky gradient. Keep shared materials, so the Compatibility renderer can batch.
- Inside the sim: each tower keeps the list of road cells in its reach, rebuilt only when towers change. Walkers are bucketed by cell each tick, so targeting checks nearby creatures, not all of them. Flyers, being few, are checked directly.

### 9.4 How to measure

1. **Sim, headless:** a benchmark tool in tools/balance/ plays each level's largest wave with a bot's build and prints the mean and 99th percentile ms per tick and the peak live creatures.
2. **On the phone:** the same tool writes game_level.json through `SaveStore` just before the largest wave starts. Push it into a debug build's files folder: `adb push game_level.json /data/local/tmp/`, then `adb shell run-as io.github.bartbasi.forkline cp /data/local/tmp/game_level.json files/game_level.json`. Open the game, tap Continue, set 3x. This uses the normal resume path, so the test is the real game.
3. **PerfProbe** (debug builds only) prints one line every 2 seconds during a wave: fps, 99th percentile frame ms, process ms, the sim's tick time (3.6, step 8), draw calls, objects, live creatures. At the end of each wave it prints a summary: the mean, 99th percentile and worst frame, the tick's mean, 99th percentile and worst, and the peak live creatures. Read it with `adb logcat -s godot`. Measure on the cover screen, on the inner screen, and while folding mid-wave.
4. Godot renders at the display rate by default (`application/run/max_fps=0`), which can mean 120 fps on the Fold5. The render-engineer measures both, and the DM sets `application/run/max_fps=60` if 120 costs too much heat or paces badly.
5. The render-engineer reports the numbers and the device state (screen, speed, wave) in its report.

## 10. Tests per owner

General rules (CLAUDE.md "Writing tests" applies):

- Files are `tests/<area>/test_*.gd` and extend `res://tests/base_test.gd`. Fixtures live in `tests/<area>/fixtures/`.
- Every random generator is seeded. Save tests use a folder under `user://tests/<area>/`, removed in `after_each()`, never the real save files.
- Nodes a test adds to the tree (through `Engine.get_main_loop() as SceneTree`) are freed in the same test.
- Tests compare ids, never display names.
- Run one area with `godot --headless --path . --script res://tests/run_tests.gd -- --only=sim`.

| Folder | Owner | Covers |
|---|---|---|
| tests/project/ | DM | Source headers, the LICENSE MD5 and the NOTICE lines; no network code, no unsafe loaders, and only src/ui/links.gd calls `shell_open`. Suggested: no display name from data/ appears in a string literal under src/. |
| tests/sim/ | sim-engineer | Catalog and LevelData checks with good and hostile fixtures; every map rule; distances, the tie break, the seal check and route lines; every tower, creature and boss rule of RULES 5 to 8 that the built content uses; targeting modes; bounties, clear bonus, early call bonus and refunds; lives, win, loss and star bits; same commands give the same `to_data()`; snapshot, restore and continue equals an uninterrupted run, at many ticks; hostile battle data gives null; the real stat files load; no float or random calls in src/sim/. |
| tests/save/ | sim-engineer | Atomic write; a failed rename keeps the newest save in `.tmp`; `.tmp` wins on load; the `.bak` fallback; a locked file is never overwritten; a newer format is left alone; hostile files (empty, truncated, huge, NUL, high bytes, wrong types, out of range, deep nesting, numbers past ceilings); defaults per field; counters saturate; the three saved games stay separate and `load_games` orders them; saved game round trip; an invalid saved game is deleted; the unlock rules of RULES 16. |
| tests/levels/ | level-designer | Every file in data/levels/ (and data/segments/ in phase 7) loads through `GameData` with no problems and is listed; RULES 12: heights by region, gates, waves, strengths and starting gold as in 12.3, towers as in 12.2, only towers and creatures brought by then, a new creature's first wave holds only it, never two new things in one wave, a boss only in a final wave, no group of `puff`, star 3 as in 12.4 and leaving two kinds of attacking tower usable; the spawn bound; ASCII only; Twists (phase 7). |
| tests/run/ | roguelite-engineer (phase 7) | Card, pack and run plan checks; the pool and unlocks; the same seed gives the same map, waves and offers; every top segment can be finished into a valid map; derived seeds pinned; the daily seed from a date; streak and best rules; an owed draft blocks the next wave; run save and restore. |
| tests/ui/ | ui-engineer | The `Layout.is_landscape` table (7.4); a resize mid-wave pauses, keeps `battle.to_data()` identical and every state node alive; `BattleClock` tick counts at 1x, 2x, 3x, paused and at the burst cap; each link button hands its constant to the opener exactly once, and `open()` refuses any other address; feedback URL encoding (a model name with `&cc=` stays in the body); touch targets at least `MIN_TOUCH` in both layouts at the Fold5 sizes; focus loss pauses and saves; back button order; the Continue card resumes the most recent saved game; star sentences built from data (2.7). |
| tests/render/ | render-engineer | MapView sets up for every real level headless; `cell_at` and `fit` round trip at several sizes; `sync` adds and frees nodes as creatures spawn and go, with no leak after a full wave. |
| tests/audio/ | audio-engineer | Every sound renders, is not silent and never clips; voice caps hold; disabled means silent; every event kind in 3.1 has a sound or a deliberate silence. |
| tests/theme/ | art-director | Contrast: every text pair 4.5:1 and graphic pair 3:1, including every text color the UI theme puts on a background; Outfit everywhere and the font files unmodified; every tower tier and path and every creature draws inside its box, in one color when asked, and each silhouette stays distinct from the others; the catalog ids have silhouettes in spec order, and `FLYERS` matches `flying`; route points and gate looks; the launcher icons exist at their sizes with the right transparency. |

Phase 7 adds to these folders what the "Done when" column of section 13 lists.

The balance bots in tools/balance/ are tools, not tests. They run on demand and write dated reports to docs/balance/.

## 11. Phase 5 build plan

Goal: region 1 playable (brief phase 5). Levels 1-1 to 1-6 with the Sling Post and Pumpkin Catapult (both tier 3 paths), the Scamp, Pip, Flitter and Grumblesack, gates and route lines, stars, every standard screen, saves and resume, sound, and the bots. The other towers and creatures, Twists, runs and the daily wait for phase 7. The DM runs at most four agents at once, so the work comes in three waves, and the DM integrates and runs every test after each wave.

Ready before wave 1:

- art-director: src/theme/ and tests/theme/ (done in phase 4).
- game-designer: data/stats/ for all 6 towers, 15 creatures and the rules, from RULES.md in the 2.6 shape, with the names agreed with the art director. Proof: the tests/theme/ catalog check passes, and tests/sim/ loads the files in wave 1.
- release-engineer, any time before phase 6: the export preset in 7.6. Proof: scripts/check_apk.sh exits 0 on a fresh debug APK.

**Wave 1** needs only this contract, src/theme/ and data/stats/.

| Agent | Builds | Depends on | Proves it with |
|---|---|---|---|
| sim-engineer | src/sim/ for region 1, in this order: Sim, Catalog (every field in 2.6), LevelData, RoadMap, Modifiers.check (every type in 2.8), then Battle: phases, waves and strength, spawns, walkers and flyers, the Sling Post and Pumpkin Catapult with both paths, targeting modes, damage and splash, Grumblesack's summons, economy and refunds, early calls, gates and the seal check, route lines, stars, events, `to_data` and `from_data` | 2, 3.1, 4, data/stats/ | tests/sim/ (section 10) |
| ui-engineer | The app shell: App (boot, screen switching, back button), FrontDoor, ModeScreen with Roguelite and Daily locked, InfoScreen, AboutScreen (LICENSE, NOTICE and OFL.txt), SettingsPanel, PausePanel, ConfirmDialog, Layout, Links, BattleClock | 3.6, 3.9, 7, 8 | tests/ui/ for Layout, Links, BattleClock and touch sizes; screenshots of each screen at both Fold5 sizes |
| audio-engineer | AudioService: a sound for every event kind in 3.1 and every UI sound in 3.8, menu and battle music, voice caps, the sound toggle | 3.1 event names, 3.8 | tests/audio/ |
| level-designer | data/levels/campaign.json and r1_l1 to r1_l6 from RULES 12, without Twists | 2.2 to 2.7, the ids in data/stats/ | Its tests in wave 2 |

**Wave 2** needs wave 1's src/sim/.

| Agent | Builds | Depends on | Proves it with |
|---|---|---|---|
| sim-engineer | src/save/: JsonFile, GameData (stats, levels, campaign), SaveStore (settings, progress, the three saved games), Settings, Progress with the unlock rules, SavedGame | 2.12, 3.5, 5 | tests/save/ |
| level-designer | tests/levels/, and fixes to whatever the checks refuse | LevelData.check, RoadMap, Battle | tests/levels/ |
| render-engineer | MapView and PerfProbe: the static map with MapArt, towers and creatures with Silhouettes in row order, drawn projectiles, puffs, health bars, drowsy and boost marks, route lines, the refused gate, range, selection and hint | Battle (read only), LevelData, 3.7, 3.9 | tests/render/; screenshots of each region 1 level mid-wave at both Fold5 sizes |
| ui-engineer | The battle panels: HUD (lives, gold, wave, speed, pause, the call button with its bonus), the build panel with range and cost, upgrades with before and after numbers and both paths, selling, inspect panels for towers and creatures, targeting, the wave preview | Battle commands and queries, Catalog | tests/ui/ panel tests on real Battle objects |

**Wave 3** needs wave 2.

| Agent | Builds | Depends on | Proves it with |
|---|---|---|---|
| ui-engineer | BattleScreen with MapView: taps, the gate drag with live route lines and refusal, hints and first sight cards; LevelSelect, LevelCard and EndPanel; the App flow with GameData and SaveStore: the Continue card, one saved game per mode, every save trigger in 5.1, resume paused, pause on a resize mid-wave | MapView, GameData, SaveStore, Progress | tests/ui/ (section 10); screenshots in both layouts |
| balance-analyst | The bots and the benchmark tool for region 1 | 3.3, 9.4, GameData, Battle | A dated report in docs/balance/ with seeds: each level won, three stars reached, no single tower type earning three stars alone, every tower type in some three star win, the same seed playing the same, the peak creatures and ms per tick |

Then phase 6: the DM integrates region 1 on Windows and the Fold5. The bot report goes to the game designer and level designer, who tune region 1. The render-engineer measures both Fold5 screens (9.4). The game designer does the fun review before hard stop B.

The roguelite-engineer builds nothing for region 1. Its first task is phase 7: src/run/, data/cards/, data/runs/ and tests/run/, alongside the phase 7 parts of src/save/ (sim-engineer), data/segments/ (level-designer) and src/ui/ (ui-engineer).

## 12. Open questions

Settled on 2026-10-24:

1. **The dock on 12 and 13 row maps.** The wave preview starts a build phase folded when its open form does not fit under the map, the strip is always one line, and a 13 row map keeps its bottom row scenery only (7.4, 2.4, 2.9). Why: with the test insets the room under a 13 row map on the cover is 134 px, less than any 48 dp control with its gap, so no form of the preview fits there, and the alternatives cost more. A smaller HUD cannot hold its 48 dp controls in one row, and keeping two free rows at the bottom of every tall map would waste a sixth of the map. The dock test covers every real level and the run maps (section 13).
2. **Level 2-1's call button highlight.** The call button glows whenever it offers an early call, until the first early call on that battle screen, and never in a build phase (7.4).
3. **The game designer's answers (G1).** RULES.md now matches this contract: Bubble Night's bubbles come back as a Bubbler's do (RULES 13); in portrait a build phase starts with the preview folded when it does not fit under the map (9.1); the star lines in Pause, "Normal only" on Relaxed, and the warnings (10.6); "Upgrade no towers." and the new hints of 1-2 and 1-3 (10.3, 12.4); no risk card once wave 17 has started (14.4); "reach wave N" means wave N starts (14.6); a 13 row map's bottom row is scenery only (3.1, 14.2). The G1 note at the top of RULES.md lists the approved wording that changed, for the DM to tell Bart.
4. **The plain mixed recipe and the checks for every region:** RULES 12.6.

Settled on 2026-10-25:

5. **Run targets.** Answered by G3: the bars for runs are RULES 14.8, and the bar for the daily is at the end of RULES 15.
6. **Ceilings on stacked effects.** Count, speed, health, tower stats and gold gains are clamped as they multiply and checked in `Battle.from_data` and `add_effects` (S6). A Twist on its own is checked in `Battle.create`, and starting gold is clamped too (S7). See 3.1 and 5.6. A per-wave ceiling was left out by the DM.

Open, with who answers and by when:

- **The coin glint.** DM: FUN_REVIEW_R1 item 8 calls the coin glint optional. Section 13 includes it in the render work; drop it there if Bart's approval did not cover it.

Suggestions, for the DM to decide. They are not part of the contract unless the DM takes them in:

- **A repeatable economy card in the base pool, checked on load** (architect, 2026-10-25). `RunData.check` could require a base card (`unlock` `{}`) of kind `economy` that is not `once`. Today a cards.json without one still loads, and a normal run whose unlocks add no such card cannot start: its pool fails the pool rule of 3.4, so `RunSession.start` returns null. Only tests/run/test_real_data.gd guards against this now, by pinning `gold_purse` and `tea_break`.
- **Heal marks within the heal event** (architect, 2026-10-25, for the render owner). The render's `MapView.HEAL_MARKS` should never exceed `Battle.HEAL_EVENT_IDS`, since a `healed` event lists no more ids than that (3.1). Both are 6 today. A test in tests/render/ could pin it.

## 13. Phase 7 build plan

Goal (brief phase 7): regions 2 to 4 with their bosses, a Twist for every campaign level, the roguelite mode and the daily challenge, with a balance pass after each region, and the fixes Bart approved at hard stop B (FUN_REVIEW_R1 items 2 to 6 and 8 to 10, and "Upgrade no towers."). The DM runs at most four agents at once. After each wave the DM integrates, runs every test and commits. Items have labels, such as **S1**, so later rows can name them.

Ground rules for the whole phase:

- **The region loop.** For regions 2, 3 and 4 in turn: the level designer builds the region's six levels and their Twists with tests/levels/ passing; the balance analyst runs a pass; the game designer tunes from it (RULES.md and data/stats/ in one step, and a list of level changes); the level designer applies the level changes. A region's levels may be built while the region before it is being tuned, but a region's pass starts only after that tuning has landed, so every pass measures the current numbers.
- **Every balance pass** covers every level and Twist built so far, because tuning can move older levels. Its dated report in docs/balance/, with seeds, gives every check of RULES 12.6, which defines the plain mixed recipe and each bar: for each level, the plain mixed recipe on Normal and on Relaxed, all three stars in one Normal win, no super tower, random play, length, and the largest wave, the peak live creatures and the ms per tick; for each Twist, a Normal win by some strategy; across the campaign, every tower type in some three-star win (brief section 11); and the same seed playing the same.
- **No new audio** beyond the four new event kinds. Every tower and path already has a sound (3.8), and neither RULES.md nor docs/art/THEME.md asks for region music or region sounds. S1 added four event kinds, now in 3.1: `released`, `break_started`, `sped_up` and `interest`. The audio engineer owes each one a sound or a deliberate silence, as a short task (done 2026-10-24). tests/audio/ checks every kind in 3.1, so its list of event kinds gains these four. V1 draws the ones it needs.
- **No new art** except the OPEN gate look (3.9). Every tower, path, creature and boss already has a silhouette, checked by tests/theme/.
- **DM checks on the Fold5,** both screens: region 2 after wave 2, including a fold mid-wave; a run and a daily after wave 4, including killing the app mid-wave and with a draft open, then Continue; everything at the end (the list below).

**Wave 1** is done (2026-10-24).

| Agent | Builds | Depends on | Done when |
|---|---|---|---|
| sim-engineer (done 2026-10-24) | **S1**: src/sim/ for phase 7. Every tower (Bell slows, Longbow armor piercing, Firework air splash, Bakery boosts), creature rule (bubbles, Puffball splits, heals, gate breakers), boss (Ironshell's speed ups, Moon Moth's flyer summons, Old Tusk's breaks and release), broken gates and mending, every Twist and card effect of 2.8 (Twists in `Battle.create`, cards and risk cards in `add_effects`), and save and restore for all of it. The DM adds this revision's sim items: `stars_possible()` and `loses_star3()` (3.1), and 2.8 as revised on 2026-10-24: which creatures each effect reaches, `add_group`'s order, `after_last` and entrance, the risk reward inside `wave_cleared` gold, the early call bonus from `bounty_pct` bounties, interest after the clear bonus, the floors, the `break_ms` check, and Bubble Night (RULES 13). Follow-ups, done 2026-10-24: the 0 to 1,000 checks of 2.8 on `add_gold` (`amount` and `per_wave`), `add_lives`, `reward_gold` and the `interest` max; and from G1, `count_pct` leaving added groups at their card's count (2.8), and at most one shot a tick with the reload timer 0 to `reload_ms * 100` between ticks and in saves (3.1, 5.6). | 2.6 to 2.8, 3.1, 4, 5.6 | tests/sim/: every rule and effect; both queries for every `star3` kind, including a tower sold after going above a tier cap; snapshot, restore and continue equal to an uninterrupted run on battles with every new tower, creature, boss and effect |
| game-designer (G1 done 2026-10-24), then art-director (A1 done 2026-10-24) | **G1**: answers the open questions of section 12 (now settled items 3 and 4), and brings RULES.md in line with this revision. Then **A1**: `MapArt.Gate.OPEN` (3.9). | this contract | G1: RULES.md updated, the DM checks it against this contract. A1: tests/theme/ with the OPEN look, and a picture of all six gate looks |
| roguelite-engineer (done 2026-10-24) | **R1**: src/run/ except RunSession: RunSeeds, RunData (every load check of 2.9 to 2.11), MapAssembler, Daily; data/runs/run.json and data/cards/cards.json (2.10, 2.11); tests/run/ with fixture segments and packs. Follow-up, with R2: `RunPacks.spawn_total` counts an added group at its card's count (2.8, 3.4). No card holds both `count_pct` and `add_group`, so no data changes. | 2.9 to 2.11, 3.4; LevelData and `Modifiers.check` (built) | tests/run/: good and hostile fixtures for every check; derived seeds pinned; the boss, segment and pack picks pinned for fixed seeds; the same seed gives an equal level; the daily seed from a date; `is_better`, `streak_after` and `shown_streak`; the real run.json and cards.json pass `RunData.check` |
| level-designer (done 2026-10-24) | **L1**: the Twists of region 1 (2.8 table); region 2, r2_l1 to r2_l6 with their Twists (RULES 12, 13), added to campaign.json; the hints of 1-2 and 1-3 (FUN_REVIEW_R1 items 6 and 10) | 2.3 to 2.8, RULES 12 and 13 | `GameData` loads every file with no problems, and the data checks in tests/levels/ pass. The checks that play levels run in wave 2. |

**Wave 2** needs S1, G1 and A1.

| Agent | Builds | Depends on | Done when |
|---|---|---|---|
| ui-engineer (done 2026-10-24) | **U1**: the approved fixes: star lines in Pause and the warnings (2.7, item 2) on the new queries, the call button look (item 3), "Upgrade no towers." in `StarText` (item 4), the hint placement (item 5), the gate chip's tap sentence (item 6), the wave cleared message (item 8), the Relaxed line on a loss (item 9); the preview that folds when it does not fit and the one line strip (7.4); the call button highlight (7.4). Also every region of campaign.json in LevelSelect with its unlock (RULES 16), the numbers of the Bell, the Bakery and the new creatures in the panels (RULES 9.3, 9.4), and the new towers and creatures in InfoScreen. | S1, G1, L1 | tests/ui/ for each item; the dock test (`_stays_in_sight`) on every real level and every wave, and on a 13 row fixture whose bottom row is scenery, checking that the strip is one line; screenshots at both Fold5 sizes: a region 2 build phase, a wave, Pause with star lines, 2-1 with the glowing call button |
| render-engineer (done 2026-10-24) | **V1**: MapView for what is new: the shots of the Longbow Loft and the Firework Tower and their paths (one arrow, the Giant Bow's, the Triple Bow's three; a burst, the Star Bloom's, the Skyrocket), Mender heals (`healed`), a gate being broken and the moment it breaks (`gate_broken`), the gate looks in the order of 3.7 (today MapView picks FIXED before BROKEN and has no OPEN), with `MapAtlas.add_gates()` looping over `MapArt.Gate.size()` (it loops over 5 today) so the OPEN look reaches the atlas, and the coin glint (item 8). Drowsy marks, boost marks, bubbles, splits, releases and the new creatures and bosses use what region 1 built; V1 checks each of them on fixtures. | S1, A1 | tests/render/ with a fixture for each new tower, path, creature and boss, and no node leak after a full wave of each; the gate look order of 3.7, including a broken locked gate and a locked gate under `gates_open`, and all six looks in the atlas; screenshots at both Fold5 sizes, mid-wave |
| level-designer | **L2**: tests/levels/ for region 2 and the Twists of regions 1 and 2 (RULES 12 and 13, the 13 row rule, two attacking towers left usable), and the fixes they need | S1, L1 | tests/levels/ |
| roguelite-engineer (done 2026-10-24) | **R2**: RunSession (3.4). Follow-up, done 2026-10-24: a pool must hold an economy card that is not `once`, and `card()` and `drafts_owed()` are public (3.4). | S1, R1 | tests/run/: owed drafts with early calls, including a wave cleared while another runs; the risk rule once wave 17 has started; eligibility; offers pinned for fixed seeds; a whole fixture run played twice with the same seed and picks ends in equal state; save and restore mid-wave and with a draft open equal to an uninterrupted run; hostile run data gives null |

**Wave 3** needs wave 2.

| Agent | Builds | Depends on | Done when |
|---|---|---|---|
| balance-analyst (running) | **B1**: the region 2 pass (region 1 again, and the Twists of regions 1 and 2); the bots extended to the new towers and to Twists | L2; the checks of RULES 12.6 | the pass report described above |
| sim-engineer (done 2026-10-24) | **S2**: src/save/ for phase 7: `GameData.run` (2.12), `SavedGame.run`, `DailyRecord.record_finish` (3.5), `SaveStore.load_daily` and `save_daily`, the 5.5 and 5.6 rules | R2 | tests/save/: run and daily saves round trip; hostile seeds, days, pools and picks refused; the daily record with an earlier, the same and a later day; a daily resumed after midnight keeps its day |
| level-designer (done 2026-10-24) | **L4**: data/segments/: the segments, index.json and packs.json (2.9), with at least 4 packs a band and a band 6 pack for each boss | R1 | the real files pass `RunData.check`; tests/levels/: every file listed, every stack valid, every choice of packs keeps the new creature rule, every bottom segment's last row is scenery |
| ui-engineer (done 2026-10-24) | **U2**: Twists in the UI (LevelCard, playing one, EndPanel, `record_twist`) and the run screens on RunSession: RunCard, DraftPanel, `BattleScreen.set_run`, the risk row and chip, and the run and daily end panels (3.6) | S1, R2 | tests/ui/: a Twist starts with its effects and records its win; on a fixture run a draft blocks the next wave and back opens Pause instead of skipping it, a pick adds its card, the risk row shows; screenshots |

**Wave 4** needs wave 3.

| Agent | Builds | Depends on | Done when |
|---|---|---|---|
| game-designer | **G2**: region 2 tuning from B1 | B1 | RULES.md and data/stats/ changed in one step, with a list of level changes |
| level-designer | **L3**: region 3, r3_l1 to r3_l6 with their Twists and tests/levels/; region 2's level changes from G2 as soon as they land | L2, G2 | tests/levels/ |
| ui-engineer | **U3**: the App flow for runs and the daily (3.6 steps 2, 3 and 5): seeds, pools, saves, the Continue card, counters and the daily record at the end, the Daily button's best and streak; `App.RUNS_BUILT` set true. BattleScreen takes card names and texts from `run.card()` and the owed count from `run.drafts_owed()`, so `set_run` takes the run only (3.6). | S2, U2 | tests/ui/: a run and a daily start, save, resume paused at 1x, end and record their counters and the daily record; Continue resumes the most recent of the three saved games; the dock test also on the run maps of 10 fixed seeds; screenshots |
| balance-analyst | **B2**: the first run and daily report, with the real segments, packs and cards | L4, R2 | for 50 seeds, the same seed plays the same (map, waves, offers, and equal state after equal picks); win rates by strategy on Normal and Relaxed, with no unlocks and with all; run length at 1x; the peak live creatures with each risk card; card pick and win rates; the daily seeds of the next 400 days and how many some strategy wins |

From wave 5 the work is the rest of the two loops. The DM starts each step when what it depends on is in, at most four agents at once.

| Step | Agent | Builds | Depends on | Done when |
|---|---|---|---|---|
| **B3** | balance-analyst | The pass over regions 1 to 3 and every Twist so far, which also confirms G2 | L3 | the pass report |
| **G3** | game-designer (done 2026-10-25) | Run tuning from B2: the run targets of section 12 in RULES 14, and changes to cards, the run plan, packs and segments for their owners (docs/design/TUNING_RUNS.md). The two questions from the level designer's quick runs are settled: the final boss and the late gold by G3 (commit 3f202fb: each boss wave sets its own strength, and lives never rise above the start), and the run length by Bart on 2026-10-25 (RULES 14.1). | B2 | RULES.md and a list of changes |
| **S3** | sim-engineer (done 2026-10-25) | The lives cap of G3 (TUNING_RUNS 3.2): `add_lives` never lifts lives above `start_lives`, and a saved battle above it loads unchanged (2.8, 5.6) | G3 | tests/sim/ |
| **R3** | roguelite-engineer (done 2026-10-25) | G3's changes to data/cards/ and data/runs/, and in src/run/ the boss wave strength and the wave 17 limit (2.9, 2.10, 3.4) | G3 | tests/run/ |
| **L5** | level-designer (done 2026-10-25) | G3's changes to data/segments/ (commit fdbfec7; the differences from the plan are in TUNING_RUNS 3.4a) | G3 | tests/levels/ |
| **S4** | sim-engineer (done 2026-10-25) | Findings L1 and L2 of the security review (docs/reviews/security-2026-10-25.md) in `Battle.from_data`: live creatures plus creatures still to come from releases at most 4,000, at most 8 creatures that summon, and the seal check in a wave too (4.4, 5.6) | the security review | tests/save/: the review's two tampered saves are refused, and real play at its worst moments still loads |
| **R4** | roguelite-engineer (done 2026-10-25) | Finding N1 of the security review: `RunSession.from_data` ties the battle's kept card effects, its waiting risk card and each running wave's risk card to the picks (5.6) | the security review | tests/run/: the review's repro and each mismatch are refused, and real run and daily saves at every point load and play on the same |
| **S5** | sim-engineer (done 2026-10-25) | Findings L5, L6, N7 and N8 of the second security review (docs/reviews/security-2026-10-25-2.md) in `Battle.from_data`: the crowd counted with what each creature can still let out, at most 8 creatures that summon and 40 that heal on the map at once, the saved level's waves included, and the seal check on every placed gate. Also a heal event lists at most 6 ids, and a summoned creature cannot heal (2.4, 2.6, 3.1, 4.4, 5.6) | the second security review | tests/save/: the review's tampered saves are refused, a heal tick at the load ceiling stays cheap, real play at its worst moments still loads, and real levels and runs stay far below both ceilings; tests/sim/: the heal event's ids and the summon rule |
| **S6** | sim-engineer (done 2026-10-25) | The ceilings on stacked effects (section 12): stacked `count_pct`, `speed_pct`, `health_pct`, `bounty_pct`, `clear_bonus_pct` and `tower_pct` effects clamped as they multiply, so no product overflows; the wave effect and kept effect ceilings checked in `Battle.from_data` and `add_effects`; and gold held at most 1,000,000,000 at every gain (3.1, 5.6) | section 12 | tests/sim/: stacked effects clamp and never overflow; each ceiling is refused past its edge, at load and by `add_effects`, and a refused card gives nothing, not even its instant gold; gold stops at 1,000,000,000 and the save still loads; tests/save/: every real level with and without its Twist, every pack, every risk card and the whole card stack stay far below each ceiling, and they load |
| **S7** | sim-engineer (done 2026-10-25) | The two gaps the architect found after S6, in `Battle.create`: every wave with the Twist alone is checked against the wave effect ceilings of 5.6, so no battle starts that no save of could load, and starting gold is held at most BIG after each `start_gold_pct` step and after Relaxed (3.1) | S6 | tests/sim/: `create` refuses a Twist past a wave ceiling, also when only the last wave passes it, and starting gold stops at BIG and the battle still saves and loads, on Normal and Relaxed; tests/save/: every real level creates with and without its Twist, on Normal and Relaxed |
| **G4** | game-designer | Region 3 tuning from B3 | B3 | as G2 |
| **L6** | level-designer | Region 3's level changes, then region 4, r4_l1 to r4_l6 with their Twists and tests/levels/ | G4 | tests/levels/ |
| **B4** | balance-analyst | The pass over all 24 levels and every Twist, and the second run and daily report | L6, S3, R3, L5 | both reports |
| **G5** | game-designer | Region 4 and the last run tuning | B4 | as G2 and G3 |
| **L7, R5** | their owners | G5's changes | G5 | their tests |
| **B5** | balance-analyst | The final confirmation of every check below, and the benchmark's largest wave across all levels, Twists and run packs with the largest risk card, written as a saved game for the phone (9.4) | L7, R5 | the report, and the saved game file |
| **V2** | render-engineer | The Fold5 measurement of that wave at 3x on both screens and while folding (9.2, 9.4). If the sim's 99th percentile tick is over 2 ms, the sim engineer speeds up the sim first (9.2). | B5 | the numbers within 9.2, in its report |

Phase 7 is done when:

- All headless tests pass, exit code 0.
- The bots confirm every check of RULES 12.6 for every campaign level and Twist. That covers brief section 11: every level can be won and reach three stars, no single tower type gets three stars alone, every tower type appears in some three-star win, and every Twist can be won on Normal.
- The bots confirm runs and the daily seed are winnable to the run targets of section 12, and that the same seed always plays the same.
- 60 fps on the Fold5 during the largest wave of the game, on both screens (V2).
- Killing the app mid-wave in a level, a run and a daily, then reopening, resumes at the exact moment, paused, at 1x.
- Folding and unfolding mid-wave switches the layout without losing state, in a level and in a run with a draft open.
- The dock test passes on every real level and on the run maps.
