# Forkline: Architecture

Owner: architect. Status: final for phase 5, 2026-10-23.

This is the contract every agent builds against: folders and owners, ids and data files, every public class with its methods and data shapes, routing, saves, resume, orientation, outbound links, the performance budget, the tests and the phase 5 build plan. Do not invent a public method that another area must call. If you need a change here, put it in your report for the DM.

Sources: docs/BRIEF.md, CLAUDE.md (with Bart's hard stop A decisions), docs/design/RULES.md and docs/art/NAMES.md. RULES.md holds every game rule and number, and it wins over this document on every rule. If the two disagree, this document has a bug: report it. "RULES 7.3" means section 7.3 of RULES.md.

Parts marked (phase 7) belong to the roguelite mode, the daily challenge or Twists. Phase 5 code never names a phase 7 class or field.

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
| Cards (phase 7) | The RULES.md card name in id form, for example `spare_gate`, `crowded_night` |

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
| id | id | equals the file name | 2.2 |
| name | text | 1 to 24 characters | |
| grid | array of strings | 8 to 13 rows of 7 characters | 2.3 |
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

### 2.5 Campaign order: data/levels/campaign.json (level-designer)

```json
{"format": 1, "regions": [
  {"id": "lantern_hill", "name": "Lantern Hill", "levels": ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6"]}
]}
```

Regions and levels in play order. Every listed level exists, and every level file is listed exactly once. The last level of a region is its boss level. The unlock rules are RULES 16, with the star counts in rules.json.

### 2.6 Stats: data/stats/ (game-designer)

Every number comes from RULES 4 to 6. Unknown keys are errors (they catch typos). A missing optional field is 0, false or empty, except `targets`, which is 1.

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

- A tower has `id`, `name`, `plural` (for the star line "Build no ..."), `info`, `kind` (`attack`, `slow` for the Bell, `boost` for the Bakery), `tiers` (exactly 2: the build, then the tier 2 upgrade) and `specs` (exactly 2 tier 3 paths, spec 0 first, each with `id`, `name` and `info` plus a stat block). `cost` is the price of that step.
- Stat block fields:

| Field | Kinds | Meaning | RULES |
|---|---|---|---|
| cost | all | Price, a multiple of 10 | 4.6 |
| reach | all | Range, Bell ring or Bakery reach | 5.2, 5.5, 5.8 |
| hits | attack, slow | `ground`, `air` or `both` | 5.1, 6.5 |
| damage, reload_ms | attack | Per hit, and the reload time | 5.2 |
| splash | attack | Splash radius, 0 for one target | 8.4 |
| targets | attack | Creatures per shot, 1 to 3 | 8.2 |
| pierce | attack | true: ignores armor | 8.3 |
| slow_pct, slow_ms | attack, slow | The slow given, with this much time left: a Bell gives it every tick, a Jam Pot to each walker it damages | 8.5 |
| boost_pct, boost_damage | boost | Attack rate and damage added to attacking towers in reach | 8.6 |

`enemies.json`:

```json
{"format": 1, "enemies": [
  {"id": "scamp", "name": "Scamp", "info": "A small night creature. Each one that gets through costs a life.",
   "health": 40, "armor": 0, "speed": 100, "lives": 1, "bounty": 5},
  {"id": "grumblesack", "name": "Grumblesack", "info": "Huge and slow. Drops 2 Scamps every 6 seconds.",
   "health": 2000, "armor": 0, "speed": 40, "lives": 20, "bounty": 100, "boss": true,
   "summon": {"enemy": "scamp", "count": 2, "every_ms": 6000, "gap_ms": 300}}
]}
```

| Field | Meaning | RULES |
|---|---|---|
| id, name, info | | 6.6 |
| health, armor, speed, lives, bounty | Numbers at strength 100 | 6.1, 6.3 |
| flying | A flyer (4.6) | 6.5 |
| boss | A boss. It comes only in a final wave. | 6.3 |
| bubble | Starts with its bubble up. The bubble comes back `bubble_ms` (rules.json) after it pops. | 6.2 |
| heal, heal_reach, heal_ms | Every `heal_ms`, the first time `heal_ms` after it appears, every other creature within `heal_reach` gains `heal` (at strength 100), up to its max health | 6.2 |
| split_into, split_count, split_gap_ms | Released where it is defeated: one at once, then one every `split_gap_ms` | 6.2 |
| break_ms | A gate breaker (4.5) | 7.7 |
| summon | `{"enemy", "count", "every_ms", "gap_ms"}`: the first time `every_ms` after it appears, then every `every_ms`, `count` creatures `gap_ms` apart | 6.3 |
| speed_up | `{"at_pct": [75, 50, 25], "add": 10}`: the first time health falls to each percent, speed rises by `add` from the next tick | 6.3 |
| release | `{"at_pct": 50, "enemy", "count", "gap_ms"}`: once, starting on the next tick, even if the same hit defeats it | 6.3 |

`rules.json`, every key required:

```json
{"format": 1,
 "start_lives": 20, "relaxed_lives_pct": 200, "relaxed_gold_pct": 150,
 "refund_pct": 70, "early_bonus_pct": 50, "clear_bonus": 20, "clear_bonus_per_wave": 5,
 "star2_lives": 15, "max_waves_running": 2, "max_gates": 3, "bubble_ms": 2000,
 "region_stars": [0, 6, 12, 18], "run_stars": 12}
```

| Key | Rule | RULES |
|---|---|---|
| start_lives, relaxed_lives_pct | Lives in the campaign and runs. Relaxed doubles them. | 4.4, 11 |
| relaxed_gold_pct | Relaxed starting gold: Normal times 150 / 100, rounded up to a multiple of 10 | 11 |
| refund_pct | Refund for every purchase not made in the current build phase, rounded down | 4.6 |
| early_bonus_pct | Early call bonus: this percent of the bounty of the newest wave's creatures still on the map, rounded up | 4.9 |
| clear_bonus, clear_bonus_per_wave | Clear bonus: (20 + 5 x wave number) x strength / 100, rounded half up | 4.5 |
| star2_lives | Star 2 | 10.2 |
| max_waves_running | Waves on the map at once | 4.9 |
| max_gates | Most gates a level or run gives | 7.1, 14.5 |
| bubble_ms | Time until a bubble comes back | 6.2 |
| region_stars | Stars each region needs, with the previous region's last level cleared | 16 |
| run_stars | Stars that open the roguelite and the daily | 16 |

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
| `tier_at_most` | `value`, 1 or 2 | No tower above tier N. | No tower went above tier N. |
| `early_calls_at_least` | `value` | Call N waves early. | At least N waves were called early. |
| `kinds_at_most` | `value` | Use at most N kinds of tower. | At most N tower types were built. |
| `gates_whole` | none | Use every gate and keep them whole. | At the start of every wave every gate was placed, and no gate broke. |

`value` is 0 to 100. RULES 10.3 also asks every challenge to leave two kinds of attacking tower usable. tests/levels/ checks that.

### 2.8 Effects: Twists and cards

A Twist or a card is a list of effects. Each effect is an object with a `type` from this closed list and exactly the fields shown. The sim implements each type once.

Uses: **Twist** effects last the whole level. **card** effects last the rest of the run, or change the state once where the table says instant. **risk** effects (the effects of a risk card) wait for the next wave that starts and change only that wave. At most one risk card waits at a time.

| type | Fields | Use | What it does | RULES |
|---|---|---|---|---|
| `start_gold_pct` | pct | Twist | Starting gold times pct / 100, rounded down to a multiple of 10 | 13 |
| `set_lives` | lives | Twist | Normal starting lives | 13 |
| `set_gates` | count | Twist | The gates the level gives | 13 |
| `fixed_gates` | cells | Twist | Gates start on these sockets. They cannot be moved or removed, and each one comes out of the level's gates. | 13 |
| `ban_tower` | tower | Twist | The tower cannot be built | 13 |
| `tier_cap` | tier (1 or 2) | Twist | No tower can go above this tier | 13 |
| `no_selling` | none | Twist | Towers cannot be sold | 13 |
| `count_pct` | pct, flyers, last_wave | Twist, risk | Group counts times pct / 100, rounded up. `flyers` true: groups of flyers only. `last_wave` true (Twist only): the final wave only. | 13, 14.5 |
| `health_pct` | pct | risk | Max health times pct / 100, rounded half up | 14.5, 14.6 |
| `speed_pct` | pct | Twist, risk | Speed times pct / 100 | 13, 14.5 |
| `armor_add` | amount | Twist | Armor plus amount | 13 |
| `all_bubbles` | none | Twist | Every creature starts with a bubble | 13 |
| `break_ms` | enemy, ms | Twist | That creature breaks gates in ms | 13 |
| `gates_open` | none | risk | From the start of that wave until the next build phase, gates block nothing and cannot be broken | 14.5 |
| `add_group` | enemy, count, entrance, at_ms, every_ms, after_last | risk | One more group. `after_last` true: at_ms counts from the start of the wave's last group. | 14.5, 14.6 |
| `reward_gold` | amount | risk | Paid when that wave is cleared, times its strength / 100, rounded half up | 14.5 |
| `add_tower` | tower | card | The tower can be built | 14.5 |
| `tower_add` | tower, stat, amount | card | Adds to that stat of every tier and path of the tower. stat: `damage`, `reload_ms`, `reach`, `splash`, `slow_pct`, `targets`, `boost_pct` or `boost_damage` | 14.5, 14.6 |
| `tower_pct` | tower, stat, pct | card | That stat times pct / 100, rounded half up. stat: `damage` or `reload_ms` | 14.5, 14.6 |
| `tower_hits_air` | tower | card | The tower also hits or slows flyers | 14.6 |
| `bounty_pct` | pct | card | Bounties times pct / 100, rounded half up | 14.5 |
| `clear_bonus_pct` | pct | card | Clear bonuses times pct / 100, rounded half up | 14.5 |
| `refund_pct` | pct | card | Replaces rules.json `refund_pct` | 14.5 |
| `cost_add` | build, upgrade | card | Added to every build price and every upgrade price, never below 10 | 14.6 |
| `interest` | pct, max | card | At the start of each build phase, gain pct of unspent gold, rounded down, at most max | 14.6 |
| `gates_stay` | none | card | Each time a wave starts, every placed gate becomes fixed (RULES 14.6) | 14.6 |
| `add_gates` | count | card, instant | Gain gates, never more than `max_gates` in all | 14.5, 14.6 |
| `add_gold` | amount, per_wave | card, instant | Gain amount plus per_wave for each wave cleared so far | 14.5 |
| `add_lives` | amount | card, instant | Gain lives | 14.5 |

- Order: a Twist's start effects come before Relaxed (RULES 11). Tower stats: the data, then every `tower_add`, then every `tower_pct`, then Bakery boosts on top (RULES 8.7). Creatures: the data, then strength, then effects.
- Instant effects change the state once and are not kept, so a restore never applies them twice. Every other effect is kept by the battle and saved with it.
- Checks: the type is known and allowed for its use; the fields are exact; every id exists; pct is 1 to 1,000; counts are 1 to 200; times are multiples of 50 up to 600,000; every other number is -1,000 to 1,000. `LevelData.check` also checks that `fixed_gates` cells are sockets of that level.
- In phase 5 the checks cover every type, but no region 1 level uses an effect yet.

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

- `kind` is `top`, `middle` or `bottom`, with the row count run.json sets for it. Entrances appear only in top segments, on the top or side edges, and the base only in bottom segments.
- Ports are the columns with a road cell on a segment's top row and on its bottom row, worked out from the grid. A segment fits under another when its top ports equal that segment's bottom ports exactly.
- data/segments/index.json lists every segment file: `{"format": 1, "segments": ["top_twin", "mid_split"]}`. The game loads only listed files, and tests/levels/ checks that every file in the folder is listed.
- data/segments/packs.json holds the wave packs (RULES 14.3): `{"format": 1, "packs": [{"id": "band1_scamps", "band": 1, "boss": "", "waves": []}]}`. A pack has exactly 3 waves in the level wave shape, without `strength`. `band` is 1 to 6. Band 6 packs name their `boss`. Entrance 2 means entrance 1 on a map with one entrance.
- An assembled map is a level checked with `LevelData.check`, plus RULES 14.2: 8 to 12 spots and 2 to 5 sockets. Packs get the spawn bound of 2.4 with the largest risk card applied.

### 2.10 The run plan: data/runs/run.json (roguelite-engineer, phase 7)

```json
{"format": 1, "waves": 18, "strength_start": 100, "strength_step": 10,
 "start_gold": 300, "gates": 1, "towers": ["sling_post"],
 "rows": {"top": 4, "middle": 5, "bottom": 4}, "spots": [8, 12], "sockets": [2, 5],
 "weights": {"tower": 30, "perk": 25, "gate": 10, "economy": 20, "risk": 15}}
```

Values from RULES 14.1 to 14.4. Lives and the Relaxed numbers come from rules.json.

### 2.11 Cards: data/cards/cards.json (roguelite-engineer, phase 7)

```json
{"format": 1, "cards": [
  {"id": "spare_gate", "kind": "gate", "name": "Spare Gate", "text": "Gain 1 gate, up to 3.",
   "once": false, "unlock": {}, "effects": [{"type": "add_gates", "count": 1}]},
  {"id": "sharp_pebbles", "kind": "perk", "tower": "sling_post", "name": "Sharp Pebbles",
   "text": "Sling Posts deal 2 more damage per hit.", "once": true, "unlock": {},
   "effects": [{"type": "tower_add", "tower": "sling_post", "stat": "damage", "amount": 2}]},
  {"id": "pip_parade", "kind": "risk", "name": "Pip Parade", "text": "Next wave: 24 more Pips. Reward: 100 gold.",
   "once": false, "unlock": {"counter": "stars", "at": 72},
   "effects": [{"type": "add_group", "enemy": "pip", "count": 24, "entrance": 1, "at_ms": 1000, "every_ms": 300, "after_last": false},
               {"type": "reward_gold", "amount": 100}]}
]}
```

- `kind` is `tower`, `perk`, `gate`, `economy` or `risk`. Tower and perk cards name their `tower`, for the draft rules in RULES 14.4. `once`: gone for the run after it is taken.
- `unlock` is `{}` for the base cards (RULES 14.5), or `{"counter": name, "at": n}` (RULES 14.6). Counter names: the five progress counters (5.5), plus `stars` and `twists_cleared`, worked out from the level records.

### 2.12 How data is checked on load

1. `GameData.load_from()` (src/save/) reads every bundled file through `JsonFile.read()`: a size cap first, ASCII only, then Godot's JSON parser. Never `load()`, `ResourceLoader`, `str_to_var` or anything that can make objects.
2. It hands each parsed value to its owner's check, in this order: `Catalog.check` (stats), `LevelData.check` (each level), the campaign list (GameData itself), then in phase 7 `RunData.check` (segments, packs, run plan and cards).
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
- Two timers run at a changing pace, so they count in 1/100 ms. A tick takes `50 * (100 + rate boost)` off a tower's reload timer, and a shot adds `reload_ms * 100` (RULES 5.2). A tick takes `50 * (100 - slow)` off a breaker's break timer (RULES 7.7). Every other timer counts whole ticks.
- No product comes near 2^62: positions stay below 300,000, and the ceilings in 2.4 and 5.5 bound every input.

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
class_name Catalog extends RefCounted                  # src/sim/catalog.gd: data/stats/, checked
static func check(towers: Variant, enemies: Variant, rules: Variant) -> PackedStringArray   # every problem; empty when valid
static func from_data(towers: Variant, enemies: Variant, rules: Variant) -> Catalog         # null when check() finds anything
func tower(id: StringName) -> TowerType                # null when unknown
func enemy(id: StringName) -> EnemyType                # null when unknown
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
```

```gdscript
class_name Battle extends RefCounted                   # src/sim/battle.gd: one map being defended
enum Phase { BUILD, WAVE, WON, LOST }
const FORMAT: int = 1
const DONE: StringName = &"done"                       # a command was carried out (not OK, which would shadow Godot's OK)

# Fixed for the whole battle. Read only.
var level: LevelData
var catalog: Catalog
var map: RoadMap
var relaxed: bool

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
var record_events: bool = true                         # bots set false for speed

static func create(level: LevelData, catalog: Catalog, relaxed: bool, twist_effects: Array[Dictionary]) -> Battle
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

# Save (section 5.6). All or nothing.
func to_data() -> Dictionary
static func from_data(data: Variant, catalog: Catalog) -> Battle   # null when any field is invalid
```

- `create` sets the starting numbers: a Twist's `start_gold_pct`, `set_lives`, `set_gates` and `fixed_gates` first, then Relaxed (RULES 11). Lives come from rules.json. A run's map carries its own start gold, gates and towers (3.4).
- Tower numbers (`numbers`, `before`, `after` and `tower_numbers`) hold the tower's own stats with card effects: `damage`, `reload_ms`, `reach`, `splash`, `targets`, `pierce`, `slow_pct`, `slow_ms`, `hits_ground`, `hits_air`, `boost_pct`, `boost_damage`. `tower_numbers` adds `got_pct` and `got_damage` (the best Bakery boosts it gets), `boosting` (towers a Bakery boosts now), `spent`, `sell` and `aim`. The UI works out the rate as `(100 + got_pct) * 1000 / (100 * reload_ms)` attacks a second (RULES 5.2, 9.3).
- `enemy_numbers(id)`: `health`, `max_health`, `armor`, `speed` (now, with slows and effects), `base_speed`, `flying`, `lives`, `bounty`, `heal`, `slow_pct`, `slow_ms` (left), `bubble` (up), `bubble_ms` (until it is back), `breaking_ms` (left, 0 when not breaking). RULES 9.4.
- `wave_preview(index)`: one row per group in spawn order, `{"enemy": StringName, "count": int, "entrance": int (1 based), "health": int, "bounty": int, "heal": int}`, at that wave's strength with the Twist and, for the next wave, a waiting risk card applied (RULES 9.1).
- `result()["stars"]` holds bits: 1 for star 1, 2 for star 2, 4 for star 3 (2.7).

```gdscript
class_name TowerState extends RefCounted               # src/sim/tower_state.gd, read only outside src/sim/
enum Aim { FIRST, LAST, STRONG }                       # RULES 8.2; FIRST is the default
var cell: Vector2i
var type: StringName
var tier: int                                          # 1, 2 or 3
var spec: int                                          # -1 below tier 3, else 0 or 1
var aim: Aim
var reload: int                                        # 1/100 ms until it may fire; 0 or less is ready
var spent_now: int                                     # bought in the current build phase: refunded in full
var spent_before: int                                  # every other purchase: refunded at the refund percent

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
| `&"gates_locked"` | A gate command outside BUILD. The UI says "Gates are locked until the wave is over." (RULES 7.6) |
| `&"not_a_socket"`, `&"has_gate"`, `&"no_gate"` | No socket there, the socket has a gate, or no gate there. |
| `&"no_gates_left"` | No gate in hand. |
| `&"fixed_gate"` | That gate cannot be moved or removed. |
| `&"would_seal"` | Some entrance would lose its last open route. The UI says "That would close every road." (RULES 7.4) |
| `&"no_more_waves"` | Every wave has started. |
| `&"still_spawning"` | The newest wave has not spawned all its groups (RULES 4.9). |
| `&"too_many_waves"` | `max_waves_running` waves are on the map. |
| `&"risk_waiting"` | A risk card is already waiting. |
| `&"bad_effect"` | An effect fails its check. |

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
| `&"healed"` | `id: int` (the Mender), `ids: Array[int]` |
| `&"leaked"` | `id: int`, `enemy: StringName`, `lives: int` |
| `&"gate_broken"` | `cell: Vector2i` |
| `&"wave_cleared"` | `wave: int`, `gold: int` |
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
- Twists (phase 7): pass `level.twist_effects` to `create`. Runs (phase 7): `RunSession.start(...)`, the same loop through `session.start_next_wave()`, and `session.pick()` at each draft.
- Each bot run prints its seeds, so every number in a docs/balance/ report can be repeated.

### 3.4 Runs, cards and the daily: src/run/ (roguelite-engineer, phase 7)

Seeds:

- A normal run's seed is one `randi()` from a freshly randomized `RandomNumberGenerator`: the only unseeded draw in the game. It is saved with the run.
- The daily seed is the local date as YYYYMMDD, for example 20261023 (RULES 15). The App reads the date with `Time.get_date_dict_from_system()` and passes the day key in. src/run/ never reads the clock.
- Every other generator is seeded with `RunSeeds.derive(run_seed, tag, index)`, which is `("%d:%s:%d" % [run_seed, tag, index]).hash()`. Tags and indexes: `"map"` 0, `"boss"` 0, `"pack"` the band (1 to 6), `"draft"` the wave just cleared (1 to 17). A test pins a few values, so an engine change to `String.hash()` is caught. Only `randi()` and `randi_range()` are called on these generators.
- So the map, the waves and each draft's random numbers depend only on the run seed (RULES 14.4). Picks change which cards are eligible, never the numbers drawn.

Drafts (RULES 14.4): each of waves 1 to 17 owes a draft when it is cleared. Owed drafts open one at a time, in wave order, in the next build phase; a draft with no build phase after it never opens. While a draft is owed, the next wave cannot start: `RunSession.start_next_wave()` refuses with `&"draft_waiting"` in either phase, and the UI says "Pick your card after this wave." The pool is fixed at run start: the base cards plus the unlocked ones for a normal run, every card for the daily (RULES 15).

```gdscript
class_name RunSeeds extends RefCounted                 # src/run/run_seeds.gd
static func derive(run_seed: int, tag: String, index: int) -> int
static func day_key(date: Dictionary) -> String        # a Time date dictionary to "2026-10-23"
static func is_day_key(text: String) -> bool           # a real calendar date from 2026-01-01 to 2200-12-31
static func daily_seed(day: String) -> int             # "2026-10-23" to 20261023
static func day_number(day: String) -> int             # days since 1970-01-01, for "the day after"

class_name RunData extends RefCounted                  # src/run/run_data.gd: segments, packs, run plan and cards, checked
static func check(files: Dictionary, catalog: Catalog) -> PackedStringArray   # files: each parsed file by its name
static func from_data(files: Dictionary, catalog: Catalog) -> RunData         # null when check() finds anything
func card(id: StringName) -> Dictionary                # {} when unknown
func card_ids() -> Array[StringName]
func pool(counters: Dictionary) -> Array[StringName]   # the base cards plus every card whose unlock the counters meet

class_name MapAssembler extends RefCounted             # src/run/map_assembler.gd
static func assemble(run_seed: int, data: RunData, catalog: Catalog) -> LevelData   # map, 18 waves and the boss; a checked level

class_name RunSession extends RefCounted               # src/run/run_session.gd: one run around its Battle
static func start(run_seed: int, daily: bool, relaxed: bool, pool: Array[StringName], data: RunData, catalog: Catalog) -> RunSession   # a daily is always Normal
var battle: Battle                                     # read only
var run_seed: int
var daily: bool
var day: String                                        # the day the daily belongs to; "" for a normal run
var picks: Array[StringName]
func draft_open() -> bool                              # a draft is owed and the battle is in BUILD
func offers() -> Array[StringName]                     # the open draft's 3 cards
func pick(card_id: StringName) -> StringName           # Battle.DONE or &"not_offered"; adds the card's effects to the battle
func start_next_wave() -> StringName                   # &"draft_waiting" while a draft is owed, else Battle.start_next_wave()
func result() -> Dictionary                            # {"won": bool, "waves": int (cleared), "lives": int, "reached": int, "risks": int}
func to_data() -> Dictionary                           # without the battle
static func from_data(data: Variant, battle: Battle, run_data: RunData) -> RunSession   # null when invalid

class_name Daily extends RefCounted                    # src/run/daily.gd: RULES 15
static func is_better(a: Dictionary, b: Dictionary) -> bool   # a win beats a loss; between wins more lives; between losses more waves; a tie keeps b
static func streak_after(streak: int, last_day: String, day: String) -> Dictionary   # {"streak": int, "day": String}
static func shown_streak(streak: int, last_day: String, today: String) -> int        # 0 unless last_day is today or yesterday
```

A daily run belongs to the day it started, even if it ends after midnight (RULES 15).

### 3.5 Files and saves: src/save/ (sim-engineer)

```gdscript
class_name JsonFile extends RefCounted                 # src/save/json_file.gd: the only JSON file reader and writer
## {"status": StringName, "data": Variant}. Status: &"ok", &"missing", &"locked" (exists, cannot be opened)
## or &"bad" (over max_bytes, a NUL byte or a byte of 0x80 or above, or not valid JSON).
static func read(path: String, max_bytes: int) -> Dictionary
static func write_atomic(path: String, data: Dictionary) -> bool   # section 5.3

class_name GameData extends RefCounted                 # src/save/game_data.gd: every bundled data file, checked (2.12)
static func load_from(root: String = "res://data") -> GameData
var problems: PackedStringArray                        # empty when every file is valid
var catalog: Catalog
var campaign: Array[Dictionary]                        # [{"id": StringName, "name": String, "levels": Array[StringName]}]
var levels: Dictionary[StringName, LevelData]
var run: RunData                                       # phase 7

class_name SaveStore extends RefCounted                # src/save/save_store.gd: every save file (section 5)
func _init(dir: String = "user://") -> void            # tests pass a folder under user://tests/
func load_settings() -> Settings
func save_settings(settings: Settings) -> bool
func load_progress() -> Progress
func save_progress(progress: Progress) -> bool
func load_games(game: GameData) -> Array[SavedGame]    # every valid saved game, most recent first; an invalid one is deleted
func save_game(saved: SavedGame) -> bool               # gives it the next order number, then writes its mode's file
func delete_game(mode: StringName) -> void
func load_daily() -> DailyRecord                       # phase 7
func save_daily(daily: DailyRecord) -> bool            # phase 7

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
func stars() -> int                                    # star marks over campaign levels
func level_open(game: GameData, id: StringName) -> bool   # RULES 16
func region_open(game: GameData, index: int) -> bool
func runs_open(game: GameData) -> bool                 # the roguelite and the daily
func twist_open(id: StringName) -> bool                # 3 stars on that level
func unlock_counters() -> Dictionary                   # the counters plus "stars" and "twists_cleared", for RunData.pool (phase 7)
func to_data() -> Dictionary
static func from_data(data: Variant) -> Progress

class_name SavedGame extends RefCounted                # src/save/saved_game.gd: one level or run in progress
var mode: StringName                                   # &"level", &"run" or &"daily"
var order: int                                         # higher is more recent; SaveStore sets it
var level_id: StringName                               # the campaign level; &"" for runs
var twist: bool
var battle: Battle
var run: RunSession                                    # phase 7; null for a campaign level

class_name DailyRecord extends RefCounted              # src/save/daily_record.gd (phase 7)
var day: String                                        # "" or the day of `best`
var best: Dictionary                                   # that day's best {"won", "waves", "lives"}; {} for none
var streak: int
var streak_day: String                                 # the last counted day
func record_finish(day: String, result: Dictionary) -> void   # uses Daily.is_better and Daily.streak_after
func to_data() -> Dictionary
static func from_data(data: Variant) -> DailyRecord
```

### 3.6 Screens and app glue: src/ui/, scenes/ui/ (ui-engineer)

```gdscript
class_name App extends Control                         # src/ui/app.gd, root of scenes/ui/app.tscn
## Creates GameData, SaveStore, Settings, Progress, the saved games and AudioService once and passes them down with setup().
## Routes between screens, saves on lifecycle notifications, handles the back button.

class_name Layout extends RefCounted                   # src/ui/layout.gd (section 7)
const LANDSCAPE_BELOW: float = 1.5
const MIN_TOUCH: float = 160.0                         # logical px: at least 48 dp on every screen in 7.4
static func is_landscape(window_size: Vector2) -> bool # height < 1.5 x width
static func safe_rect(viewport: Viewport) -> Rect2     # the display safe area in viewport coordinates

class_name BattleClock extends RefCounted              # src/ui/battle_clock.gd: real time to whole ticks
var speed: int = 1                                     # 1, 2 or 3; every level and run starts at 1 (RULES 4.8)
var paused: bool = false
const MAX_FRAME_SECONDS: float = 0.25                  # a long frame or a return from the background never bursts
const MAX_TICKS_PER_FRAME: int = 6
func advance(delta: float) -> int                      # whole ticks to run now; 0 while paused
func alpha() -> float                                  # 0 to 1: how far between the last tick and the next
func reset() -> void                                   # drops the leftover time

class_name BattleScreen extends Control                # src/ui/battle_screen.gd: map, HUD, panels, input
signal save_requested()                                # a build phase began, a card was picked, or Pause opened
signal ended(result: Dictionary)                       # won, lost, or abandoned from Pause after a confirm (then won is false)
signal left()                                          # the player went to the menu; the game stays saved
func setup(battle: Battle, audio: AudioService, progress: Progress) -> void
func set_run(run: RunSession) -> void                  # phase 7
func apply_layout(window_size: Vector2) -> void        # also a test hook (7.5)
func pause() -> void                                   # freezes the clock and opens Pause
func is_paused() -> bool

class_name Links extends RefCounted                    # src/ui/links.gd (section 8)
```

The other screens are used only inside src/ui/, so their signals can change without a contract change: FrontDoor, ModeScreen (the Continue card, Campaign, Roguelite, Daily), LevelSelect, LevelCard (RULES 10.5: name, waves, gates, the three star lines, stars earned, the hint, Normal or Relaxed with Normal always preselected, the Twist once open), WavePreview, InfoCard (first sight), PausePanel (Resume, Info, Settings, leave to the menu, abandon with a confirm, the quiet coffee row), SettingsPanel (sound, About), InfoScreen, AboutScreen, EndPanel, ConfirmDialog, and in phase 7 RunCard and DraftPanel.

App flow:

1. **Launch.** `GameData.load_from()`. If it has problems, show the damaged message and stop. Load settings, progress and the saved games (an invalid one is deleted), and in phase 7 the daily record. Create the AudioService (3.8). Apply `UiTheme.build()`. Show the front door. Set `get_tree().quit_on_go_back = false`.
2. **Play** opens ModeScreen. When any game is saved, the Continue card on top resumes the most recent one in one tap. A saved game also resumes from its own way in: the Roguelite or Daily button, or the saved level's card. Playing a different campaign level or Twist while one is saved asks first; a level and its own Twist count as different, since `SavedGame` has a `twist` flag. If the player confirms, the saved game ends as if abandoned from Pause, and nothing is recorded (RULES 4.10). Roguelite and Daily stay locked until `runs_open()`, and in phase 5 they stay locked.
3. **Battle.** A campaign level: `Battle.create(level, catalog, relaxed, effects)`, where `effects` is the level's `twist_effects` when playing its Twist and empty otherwise. A run or the daily (phase 7): `RunSession.start(...)`. Then `BattleScreen.setup()`. Every battle starts at 1x. A resumed game opens paused, on the Pause menu.
4. **Saving.** On `save_requested` the App saves that mode's game. On `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_WM_CLOSE_REQUEST` while a battle is open, it calls `battle_screen.pause()` if a wave is running, then saves. Settings and progress save when they change.
5. **End.** On `ended`: record the stars (`Progress.record_level`, or `record_twist` for a won Twist), the counters for a run or daily and the daily record for a daily (phase 7), delete that mode's saved game, save, and show EndPanel. An abandoned campaign level records nothing. An abandoned run or daily counts as lost at its current wave (RULES 14.7).
6. **Back button.** Close the top panel or dialog first. In a battle, open Pause. On the front door, quit; everything is already saved.
7. **Resize.** The App connects `get_tree().root.size_changed` and calls `apply_layout()` on the live screen (7.5).
8. **Debug builds** (`OS.is_debug_build()`) add a `PerfProbe` (3.7). Release builds never do.

First sight (RULES 9.2, 9.6): a tower's card opens at the start of the first level that offers it, a creature's card in the build phase before the first wave that brings it, and a level's hint at its first start. Each opens by itself once, then its id goes into `Progress.seen`.

### 3.7 Render: src/render/, shaders/ (render-engineer)

```gdscript
class_name MapView extends Node2D                      # src/render/map_view.gd
const CELL: float = 128.0                              # local px per cell; fit() scales the node
func setup(battle: Battle) -> void                     # builds the static map layer and the entity pools
func fit(rect: Rect2) -> void                          # rect in the parent's coordinates; position and scale so the map fills it
func cell_at(global_point: Vector2) -> Vector2i        # a global canvas position to a cell; (-1, -1) outside the map
func enemy_at(global_point: Vector2) -> int            # the nearest creature within reach of a finger; -1 for none
func sync(alpha: float) -> void                        # every frame: adds, moves and frees entity nodes from battle state
func play_events(events: Array[Dictionary]) -> void    # projectiles, puffs, sparkles, gate effects
func show_routes(routes: Array[Dictionary]) -> void    # Battle.routes() entries; [] hides the lines
func show_refused(cell: Vector2i) -> void              # the crossed out gate on that socket for 1.5 s (RULES 7.4)
func show_range(cell: Vector2i, reach: int, boost: bool) -> void   # reach in hundredths of a tile; boost: a Bakery's reach and the towers it would boost; (-1, -1) hides it
func show_selection(cell: Vector2i) -> void            # (-1, -1) hides it
func show_hint(cell: Vector2i) -> void                 # (-1, -1) hides it

class_name PerfProbe extends Node                      # src/render/perf_probe.gd: debug builds only (section 9)
```

- MapView draws in its own local space, where a cell is `CELL` pixels, with `MapArt` and `Silhouettes` (3.9). `fit()` changes only the node's position and scale, so a fold re-fits one transform and every child, particles in flight included, keeps its place.
- Towers and creatures draw in row order, lower on the screen in front, because a tower reaches up to 0.85 of a cell above its center. Creatures are drawn facing right; MapView flips a creature's node to face left. `frame` steps a 4 frame walk or flap cycle.

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

The art director built this. Each file's doc comments give the details. Other areas use only the members below; `InkPen` is internal to src/theme/. Everything takes ids from 2.2 and draws onto any `CanvasItem`, so src/theme/ uses nothing outside Godot's core types.

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
enum Gate { SOCKET, CLOSED, FIXED, BROKEN, REFUSED }
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
| game_level.json, game_run.json, game_daily.json | one saved game per mode (Bart, hard stop A), at the exact moment | when a build phase begins, after a card pick, when Pause opens, on focus loss, app pause and close request, and when leaving the battle. Deleted when that game ends. | 1 MB each |
| daily.json (phase 7) | the day's best daily result and the streak | when a daily ends | 4 KB |

Writes are synchronous on the main thread. The largest file is under 100 KB in the biggest wave, a few milliseconds to write. A write whose text equals the last text written to that file is skipped.

### 5.2 Reading

1. A missing file means defaults, or no saved game.
2. A file that exists but cannot be opened is **locked**. Its defaults are used in memory, and nothing in this launch writes, renames or deletes it or its `.tmp` or `.bak`, because it may hold good data.
3. A file over its cap is refused before any of it is read.
4. A NUL byte or any byte of 0x80 or above is refused before parsing. Every saved string is an id, a day key, a mode or a number in a string, so the files are plain ASCII.
5. The text goes through `JSON.new().parse()`. A parse error means invalid. Godot's parser refuses nesting past its limit cleanly (checked with 4.7.2: 600 levels parse, 2,000 fail with an error, nothing crashes). Never `str_to_var`, `bytes_to_var`, `FileAccess.get_var`, `ConfigFile`, `load()`, `ResourceLoader` or anything that can make objects from file data.
6. Then every field is checked for type, range and shape.
7. A file whose `format` is higher than this build knows is treated like a locked file, so a newer save is never overwritten by an older build. A saved game is the exception: it is deleted.

### 5.3 Writing (atomic)

1. Build the dictionary with `to_data()`: only bool, int, String, Array and Dictionary values. Vector2i becomes `[x, y]`, StringName becomes String, and an enum value becomes its lowercase name.
2. `JSON.stringify(data)` (sorted keys). Refuse to write text that is not plain ASCII.
3. Write the text to `<name>.tmp`, flush, close. Read it back and compare. On any difference, delete the `.tmp` and return false.
4. If `<name>` holds exactly the text this store last wrote or loaded as valid, rename it to `<name>.bak`. If that rename fails, carry on without a fresh backup.
5. Rename `<name>.tmp` to `<name>`.
6. **A failed rename** returns false and leaves the `.tmp` in place. It holds the newest complete save, and the next load uses it. The next write tries again. On Windows, Godot's rename removes the target, then moves the file in: it fails while another program holds the target (checked with 4.7.2: the old file stays, the `.tmp` stays), and SumUp saw it fail half way while the temp file was held (the target gone, the `.tmp` kept). On Android, Godot uses POSIX rename, which replaces the file in one step. In every case a kill at any moment leaves a complete newest save in `.tmp` or `<name>`, plus the `.bak`.
7. The App logs a failed save once per launch, not every time. No error shows to the player.

### 5.4 Loading order

Try a valid `<name>.tmp` first (it is always the newest attempt); if it is valid, rename it into place. Then a valid `<name>`. Then a valid `<name>.bak` (one save behind). A `.tmp` that fails its check is deleted. For settings, progress and daily, "valid" means a JSON object with a known `format`, and any bad field inside falls back to its own default. For a saved game, "valid" means every check in 5.6 passes. When no copy of a saved game passes, all three are deleted (`.tmp`, then `.bak`, then the file), so a bad save never comes back.

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

- `levels`: at most 512 entries, keys in id form, values 0 to 7. Unknown but well formed ids are kept and ignored, so a later version's progress survives.
- `twists`, `seen`: at most 512 ids each, no repeats.
- `counters`: the five names of RULES 14.6, each 0 to 1,000,000,000. A missing one is 0, and an unknown one is dropped.

```json
{"format": 1, "mode": "run", "order": 41, "level_id": "", "twist": false,
 "battle": {},
 "run": {}}
```

- `mode` is `level`, `run` or `daily` and matches the file name. `order` is 0 to 10^12. `level_id` is a campaign level id for `level` and `""` otherwise. `battle` holds `Battle.to_data()` (5.6). `run` is null for `level`, and `RunSession.to_data()` otherwise (phase 7).

```json
{"format": 1, "day": "2026-10-23", "best": {"won": false, "waves": 12, "lives": 0},
 "streak": 3, "streak_day": "2026-10-23"}
```

- daily.json (phase 7): `day` and `streak_day` are `""` or a real calendar date from 2026-01-01 to 2200-12-31. `best` is `{}` or the result shape with numbers 0 to 1,000. `streak` is 0 to 100,000.

### 5.6 The saved battle

`Battle.to_data()` and `Battle.from_data()` belong to the sim-engineer, and the shape inside is internal to src/sim/. The rules:

- It holds the level (`LevelData.to_data()`), so an assembled run map or a later data change never breaks a saved game. It also holds `relaxed`, the kept effects, the waiting risk card, and every field that affects a later tick: the tick, the phase, the waves started and running with their spawn counters, gold, lives, gates, towers with their purchases, creatures with every timer, queued releases, the next id, and what the star rules need.
- Positions between ticks, the distance fields and the folded effects are rebuilt on load, not saved.
- `from_data` checks everything, all or nothing:

| Field | Rule |
|---|---|
| level | passes `LevelData.check` |
| effects | at most 64 kept and 8 waiting, each passing `Modifiers.check` for its use |
| tick | 0 to 1,000,000,000 |
| phase | `build` or `wave` |
| waves and spawn counters | inside the level's waves and groups |
| gold | 0 to 1,000,000,000 |
| lives | 1 to 1,000,000 |
| gates | each on a socket, at most one per socket, at most `max_gates` placed and in hand together; in `build` the closed set does not seal |
| towers | at most the spot count; each on its own spot; a known type; tier 1 to 3; spec matching the tier and inside any cap |
| creatures | at most 4,000; ids 0 to 2^31, unique and below the next id; known types; health 1 to max health, max health 1 to 1,000,000,000; walkers on joined road cells with progress 0 to UNIT; flyers inside the map; every timer inside its data range |
| every number | whole, finite and in range, then converted to int |

`RunSession.from_data` (phase 7) checks the run the same way: a seed from 0 to 2^32, known card ids, at most 64 picks, 0 to 17 drafts owed, and a day key or `""`.

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

Why 1.5: with the HUD budgets below, the landscape layout shows the bigger map when the ratio is below about 1.5, and the portrait layout above it.

The map never rotates. The same 7 column grid shows in both layouts; only the HUD moves (RULES 3.1).

- **Portrait:** the map at full width, the HUD above and below it. With 13 rows, the HUD gets at most 590 logical px of height in total, outside the safe insets.
- **Landscape:** the map at full height inside the safe area, and one side panel at least 720 logical px wide for the HUD, the build panel and the wave preview.
- The project keeps its 1080 x 2400 base with `canvas_items` stretch and `expand`, so the cover screen is 1080 x 2767 logical px and the inner screen 1998 x 2400.
- Room for the entrance thickets (3.9) comes out of the HUD budget, or the HUD covers part of them.

Touch size, with SumUp's measured densities and the same base viewport:

| Screen | Logical px per dp | 160 px (`MIN_TOUCH`) | Map cell, 7 columns |
|---|---|---|---|
| Fold5 cover | 3.14 | 51 dp | 154 px, 49 dp |
| 20:9 phone at 2.625 | 2.63 | 61 dp | height limited: 127 px, 48 dp at 13 rows |
| Fold5 inner, landscape | 2.89 | 55 dp | height limited: about 167 px, 58 dp |
| 16:9 phone at 2.625 | 3.28 | 49 dp | height limited: 127 px, 39 dp at 13 rows |

Bart approved 7 columns by 8 to 13 rows at hard stop A, so map cells stay at 48 dp on the Fold5 cover. The table assumes the full 590 px portrait HUD and the measured insets: about 170 logical px on the cover and on phones, about 230 on the inner screen with its taskbar. Old 16:9 phones fall short on tall maps; a slimmer portrait HUD helps there (RULES 17). Taps on the map only select a cell or drag a gate; building, upgrading and selling happen on 48 dp buttons.

### 7.5 Folding and unfolding mid-wave

1. Android resizes the window. Godot keeps running (7.2).
2. The App gets `size_changed` and calls `BattleScreen.apply_layout(size)`.
3. If a wave is running and the game is not paused, `apply_layout` first calls `pause()`. Bart chose this at hard stop A. Any size change during a wave pauses, so split screen and pop-up windows behave the same as a fold.
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
- The font ships through Godot's font import: the imported FontFile keeps the TTF's bytes unchanged, next to OFL.txt in src/theme/fonts/.
- Launcher icons from the art director's committed PNGs:
  - `launcher_icons/main_192x192="res://icons/icon_192.png"`
  - `launcher_icons/adaptive_foreground_432x432="res://icons/icon_foreground_432.png"`
  - `launcher_icons/adaptive_background_432x432="res://icons/icon_background_432.png"`
  - `launcher_icons/adaptive_monochrome_432x432="res://icons/icon_monochrome_432.png"`
- `package/app_category=2` (Game, the default).
- `screen/immersive_mode=true` and `screen/edge_to_edge=false` (the defaults). The UI uses the safe area. QA checks the cover screen's camera cutout and the inner screen's taskbar inset.
- `screen/support_small`, `support_normal`, `support_large` and `support_xlarge` all true.
- `gradle_build/target_sdk` and `min_sdk` empty (36 and 24).
- `user_data_backup/allow=false` and `package/retain_data_on_uninstall=false`, so saves stay on the phone and go with an uninstall.
- No permissions.
- The APK check (scripts/check_apk.sh) confirms: `targetSdkVersion` 36, `screenOrientation` 1, `resizeableActivity` true, `appCategory` game, `configChanges` including 0x1d80 (orientation, screenLayout, screenSize, smallestScreenSize, density), no `uses-permission`, `assets/LICENSE`, `assets/NOTICE` and `assets/src/theme/fonts/OFL.txt` inside, and every file under data/ inside.

### 7.7 Sources

1. Android 16 behavior changes: https://developer.android.com/about/versions/16/behavior-changes-16
2. Android 17, restrictions on orientation and resizability are ignored: https://developer.android.com/about/versions/17/changes/ff-restrictions-ignored
3. App orientation, aspect ratio and resizability: https://developer.android.com/develop/adaptive-apps/guides/app-orientation-aspect-ratio-resizability
4. Prepare your app for the resizability and orientation changes in Android 17 (2026-02-13): https://developer.android.com/blog/posts/prepare-your-app-for-the-resizability-and-orientation-changes-in-android-17
5. Google Play target API level requirements: https://developer.android.com/google/play/requirements/target-sdk
6. Support large screen resizability for games: https://developer.android.com/games/develop/multiplatform/support-large-screen-resizability
7. The application element, `appCategory` and `isGame`: https://developer.android.com/guide/topics/manifest/application-element
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
static func open(url: String) -> void                  # the opener if set, else OS.shell_open; a failure shows nothing
static func open_coffee() -> void                      # open(COFFEE_URL)
static func open_source() -> void                      # open(SOURCE_URL)
static func send_feedback() -> void                    # open(feedback_url(version(), device_text()))
static func version() -> String                        # ProjectSettings application/config/version
static func device_text() -> String                    # "%s, %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version_alias()]
static func feedback_url(version: String, device: String) -> String
```

- Each address is a constant written once. Nothing is ever added to the coffee or source address. The feedback address is a constant too; only the subject and body of the draft carry the version and device.
- `feedback_url` returns `"mailto:%s?subject=%s&body=%s" % [FEEDBACK_EMAIL, subject.uri_encode(), body.uri_encode()]`, with subject `"Forkline feedback (version %s)" % version` and body `"\n\n\nSent from Forkline %s on %s" % [version, device]`, so the player writes above that line. `uri_encode` turns `&`, `?`, `#`, `=` and line breaks into escapes, so a strange model name cannot add a recipient or a header. The player sees and can edit everything before sending; the app sends nothing.
- Phone model: `OS.get_model_name()` (Build.MODEL, for example SM-F946B). Android version: `OS.get_version_alias()`, which on Android gives the marketing version plus the SDK and build; `OS.get_version()` gives only the SDK number and build.
- The coffee tap rules (look, deadzone, one hand-off per tap, coming back) are the playbook's section 5, applied by the ui-engineer.
- Only src/ui/links.gd calls `OS.shell_open` (checked by tests/project/). Tests set `Links.opener` to a recorder in `before_each()` and reset it to `Callable()` in `after_each()`. A lambda left in a static var crashed Updraft's engine on quit.

## 9. Performance budget

Target: 60 fps on the Fold5 (Snapdragon 8 Gen 2), on both screens, through the largest wave of the game at 3x.

### 9.1 Entity ceilings

| Thing | Budget | Held by |
|---|---|---|
| Live creatures at once, Puffs and releases included | 200 | The spawn bound (2.4): one wave spawns at most 120 counting splits, and at most `max_waves_running` (2) waves run at once. The bots report the real peak, boss releases included. |
| Towers | 24 | Build spots per map (2.3) |
| Drawn projectiles in flight | 150 | The render pools them. The sim has no shots: hits land at once. |
| Particles alive | 400 | Pooled emitters, at most 24, at most 16 particles per puff |
| Sound voices | 12 | At most 3 of the same sound at once |
| Draw calls per frame | about 200 | Measured |

### 9.2 Time per frame on the Fold5 (16.7 ms)

- Sim: at most 2 ms per frame at 3x (one tick per frame at 60 fps), with 200 live creatures. On the dev PC, headless: at most 0.5 ms per tick.
- Render and UI scripts (`sync`, events, HUD): at most 3 ms.
- GPU: at most 8 ms.
- The 99th percentile frame over the whole wave: at most 20 ms.

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
3. **PerfProbe** (debug builds only) prints one line every 2 seconds during a wave: fps, 99th percentile frame ms, process ms, draw calls, objects, live creatures. Read it with `adb logcat -s godot`. Measure on the cover screen, on the inner screen, and while folding mid-wave.
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
| tests/ui/ | ui-engineer | The `Layout.is_landscape` table (7.4); a resize mid-wave pauses, keeps `battle.to_data()` identical and every state node alive; `BattleClock` tick counts at 1x, 2x, 3x, paused and at the burst cap; each link button hands its constant to the opener exactly once; feedback URL encoding (a model name with `&cc=` stays in the body); touch targets at least `MIN_TOUCH` in both layouts at the Fold5 sizes; focus loss pauses and saves; back button order; the Continue card resumes the most recent saved game; star sentences built from data (2.7). |
| tests/render/ | render-engineer | MapView sets up for every real level headless; `cell_at` and `fit` round trip at several sizes; `sync` adds and frees nodes as creatures spawn and go, with no leak after a full wave. |
| tests/audio/ | audio-engineer | Every sound renders, is not silent and never clips; voice caps hold; disabled means silent; every event kind in 3.1 has a sound or a deliberate silence. |
| tests/theme/ | art-director | Contrast: every text pair 4.5:1 and graphic pair 3:1, including every text color the UI theme puts on a background; Outfit everywhere and the font files unmodified; every tower tier and path and every creature draws inside its box, in one color when asked, and each silhouette stays distinct from the others; the catalog ids have silhouettes in spec order, and `FLYERS` matches `flying`; route points and gate looks; the launcher icons exist at their sizes with the right transparency. |

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

1. **The font file in the APK (DM).** CLAUDE.md says Outfit[wght].ttf and OFL.txt ship unmodified, side by side. With Godot's font import, the APK holds the imported font (the TTF's bytes unchanged, inside Godot's resource) and OFL.txt as a plain file, but not the raw .ttf file. Is that enough? If the raw file must ship too, the art director sets the font's import to "Keep File" and loads it with `FontFile.load_dynamic_font()`, and 7.6 adds it to the include filter.
