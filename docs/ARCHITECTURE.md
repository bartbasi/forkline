# Forkline: Architecture

Owner: architect. Status: first draft, phase 3, 2026-10-23. The architect finalizes it in phase 4, after Bart approves docs/design/RULES.md.

This is the contract every agent builds against: folders and owners, data files, every public class with its methods and data shapes, routing, saves, resume, orientation, outbound links, the performance budget and the test layout. Do not invent a public method that another area must call. If you need a change here, put it in your report for the DM.

Sources: docs/BRIEF.md, CLAUDE.md, and the playbook sections 5, 6, 11 and 13. docs/design/RULES.md did not exist when this draft was written. Where a rule is not settled, the shape below keeps the numbers in data files, and each guess is marked **Assumed** and listed again in section 11. Where this document and RULES.md disagree on a rule, RULES.md wins and this document has a bug: report it.

## 0. Principles

1. **The rules are pure.** src/sim/ and src/run/ extend RefCounted only. No Node, no scene tree, no Input, no files, no real time and no floats in game state. The same inputs give the same result on every phone and on Windows.
2. **The sim resolves, the view follows.** Render and UI read sim state every frame and send player commands as method calls. They never write sim state.
3. **Data holds the numbers.** Towers, enemies, levels, segments, cards and the run plan are JSON files under data/, checked field by field on load.
4. **One composition root, no autoloads.** The App creates every service once and passes it down with `setup()` calls. project.godot gets no autoload and no input map entries.
5. **Files in one place.** In the game, only src/save/ opens data and save files. The one exception is About, which reads LICENSE and NOTICE as plain text. Everything else goes through the JSON parser and a field by field check.
6. **Statically typed GDScript.** Every variable, parameter and return value has a type. After adding or renaming a `class_name`, run `godot --headless --path . --import`.

## 1. Folder layout and owners

```
forkline/
  project.godot, LICENSE, NOTICE, README.md, CLAUDE.md     DM
  export_presets.cfg                                       release-engineer
  scenes/main.tscn                                         DM: holds only an instance of scenes/ui/app.tscn
  scenes/ui/                                               ui-engineer: app.tscn and every screen
  src/sim/                                                 sim-engineer: the rules engine
  src/run/                                                 roguelite-engineer: runs, cards, daily
  src/save/                                                roguelite-engineer (proposed): data loading and save files
  src/ui/                                                  ui-engineer: screens, HUD, input, layout, the App glue
  src/render/, shaders/                                    render-engineer
  src/audio/                                               audio-engineer
  src/theme/                                               art-director
  data/stats/                                              game-designer (proposed): towers, enemies, rules
  data/levels/, data/segments/                             level-designer
  data/cards/, data/runs/                                  roguelite-engineer (data/runs/ proposed)
  icons/                                                   art-director (proposed): launcher icon PNGs, generated, committed
  tools/icon/                                              art-director (proposed): the launcher icon tool
  tools/balance/                                           balance-analyst
  tools/store/, scripts/                                   release-engineer
  tests/project/                                           DM
  tests/sim/, tests/levels/, tests/run/, tests/ui/         as in CLAUDE.md
  tests/save/                                              roguelite-engineer (proposed)
  tests/render/, tests/audio/, tests/theme/                render, audio, art-director (proposed)
  prototypes/theme/                                        art-director, deleted after hard stop A
  docs/                                                    as in CLAUDE.md; docs/ASSETS.md stays with the DM
```

### 1.1 Proposed owners for the paths the brief left open

The DM records these in the CLAUDE.md table and updates the agent files.

| Path | Proposed owner | Why |
|---|---|---|
| src/ui/app.gd, scenes/ui/app.tscn (boot, screen switching, lifecycle saves, back button) | ui-engineer | It is screen flow. scenes/main.tscn stays with the DM and only instances app.tscn. No autoloads, so nothing goes into project.godot. |
| src/save/, tests/save/ (data loading, settings, progress, the saved level or run, daily results and streak) | roguelite-engineer | Most of what is saved is meta progress (stars, card pool, unlocks, daily streak), which is that agent's area, and its phase 5 load is light. All file reading lives in one folder, so the security reviewer audits one place. The alternative is the sim-engineer (Opus) if the DM wants the more careful model on this code; it would lengthen the critical path. |
| docs/ASSETS.md | DM (no change) | Every agent adds assets. Each report lists the assets it added; the DM logs them. |
| tools/icon/ and icons/ (launcher icon tool and its PNGs) | art-director | The icon is the art director's design. The tool draws it with `IconArt` from src/theme/ and is the only writer of icons/. The PNGs are committed, so a build never runs the tool. The release engineer points the export preset at them, and tools/store/ uses the same `IconArt` for the 512 x 512 store icon. |
| data/stats/ (towers.json, enemies.json, rules.json) | game-designer | Numbers get one owner, and a balance pass needs no hand-off. The loader and its checks are the sim-engineer's (`Catalog` in src/sim/). When a number changes, the game designer changes RULES.md and the JSON in the same task, then runs `godot --headless --path . --script res://tests/run_tests.gd -- --only=sim,levels`. |
| data/runs/ (run.json) | roguelite-engineer | The run plan: segment slots, run length, wave templates, boss. |
| tests/render/, tests/audio/, tests/theme/ | render-engineer, audio-engineer, art-director | Each area tests its own code. tests/theme/ holds the text contrast check. |

### 1.2 Who may use what

- src/sim/ and src/theme/ use nothing outside Godot's core types.
- src/run/ uses src/sim/.
- src/save/ uses src/sim/ and src/run/.
- src/render/ uses src/sim/ (read only) and src/theme/.
- src/audio/ uses only the event names of src/sim/.
- src/ui/ uses everything.
- tools/balance/ uses src/save/, src/run/ and src/sim/. tools/icon/ and tools/store/ use src/theme/.
- Nothing lower uses anything higher, so there are no cycles. tools/ code uses preload and adds no class names.

## 2. Data model and data files

### 2.1 Units, ids and text

- **Time** in data: milliseconds, a multiple of 50 (one tick). The loader turns it into ticks.
- **Distance and range** in data: hundredths of a cell. 250 is two and a half cells.
- **Speed** in data: hundredths of a cell per second. 100 is one cell a second.
- **Percent**: whole numbers. 30 means 30 percent.
- **Gold, health, damage, armor, lives, counts**: whole numbers.
- Every number is a JSON number with no fraction part. Godot's JSON parser returns every number as a float, so a check accepts 2 and 2.0, and refuses 1.5, NaN, infinity and anything out of range.
- **Ids**: 1 to 32 characters of `a` to `z`, `0` to `9` and `_`, starting with a letter. Unique within their kind. StringName in code.
- **Text** shown to players (names, hints, info lines, card text): printable ASCII, no tabs or line breaks. Names at most 24 characters, other text at most 80. Every data and save file is plain ASCII, checked by a test. Data text is always shown in a Label, never as BBCode.
- **Cells** in JSON are `[column, row]`. Column 0 is the left, row 0 the top. In code a cell is a Vector2i(column, row).

### 2.2 The map grid

Every map is a grid of **7 columns and 8 to 13 rows** (**Assumed**, see 7.4 for the touch size math). Rows are strings of 7 characters:

| Char | Cell | Rules |
|---|---|---|
| `.` | ground | Scenery. Nothing is built here. |
| `#` | road | |
| `G` | road with a gate socket | Not an entrance or the base. |
| `o` | build spot | Not a road. One tower per spot. |
| `1` to `4` | entrance 1 to 4 | A road cell on the map edge (**Assumed**). Numbered from 1 with no gaps. |
| `B` | base | A road cell. Exactly one per map. |

Checked on load:

- Road cells are `#`, `G`, `1` to `4` and `B`. Orthogonal neighbors that are both road cells are joined. Diagonal neighbors never are.
- No 2 x 2 block of road cells, so roads are one cell wide and routes have no hidden zigzags.
- Every entrance reaches the base with every socket open, and also with only the twist's fixed gates closed.
- At most 24 build spots and 8 sockets per map.

The sim moves creatures along the cell centers. The render may draw roads as smooth bands with rounded corners through those centers, and may round a creature's drawn path at corners by up to a third of a cell.

### 2.3 Level files: data/levels/<id>.json (level-designer)

```json
{
  "format": 1,
  "id": "r1_l2",
  "name": "Two Lanes",
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
  "start_gold": 120,
  "lives": 20,
  "gates": 1,
  "towers": ["lantern", "bakery"],
  "stars": [
    {"kind": "lives_left_at_least", "value": 15},
    {"kind": "towers_at_most", "value": 4}
  ],
  "hint": {"text": "Tap a glowing spot to build.", "cell": [3, 3]},
  "waves": [
    {"gold": 20, "groups": [
      {"enemy": "nightling", "count": 6, "entrance": 1, "at_ms": 0, "every_ms": 900}
    ]}
  ],
  "twist": {"text": "No bakeries this time.", "effects": [{"type": "ban_tower", "tower": "bakery"}]}
}
```

Ids, names and numbers in examples are placeholders. In this map both branches are 11 steps long, so with no gate placed the tie break (4.3) sends creatures right.

| Field | Type | Limits | Notes |
|---|---|---|---|
| format | int | 1 | |
| id | id | equals the file name | |
| name | text | 1 to 24 characters | |
| grid | array of strings | 8 to 13 rows of 7 characters | 2.2 |
| start_gold | int | 0 to 100000 | Normal. Relaxed scales it by `relaxed_gold_pct` in rules.json. |
| lives | int | 1 to 1000 | Normal. Relaxed scales it by `relaxed_lives_pct` in rules.json. |
| gates | int | 0 to the number of sockets | Gates the player may place. Campaign levels have at most 3 (checked in tests/levels/). |
| towers | array of tower ids | 1 to 6, no repeats | The towers this level offers. |
| stars | array of 2 star rules | `kind` from RULES.md, `value` an int | The second and third stars. The first is the win. |
| hint | object, optional | `text` 1 to 80 characters, `cell` inside the map | The one-line hint and its highlighted cell. |
| waves | array | 1 to 40 waves | |
| waves[].gold | int | 0 to 100000 | Paid when the wave is cleared (**Assumed**). |
| waves[].groups | array | 1 to 8 groups | |
| group.enemy | enemy id | must exist in enemies.json | |
| group.count | int | 1 to 200 | |
| group.entrance | int | 1 to the number of entrances | |
| group.at_ms | int | 0 to 600000, multiple of 50 | First spawn, after the wave starts. |
| group.every_ms | int | 50 to 60000, multiple of 50 | Time between two spawns of this group. |
| twist | object, optional | `text` 1 to 80 characters, `effects` 1 effect (**Assumed**) | 2.6 |

### 2.4 Campaign order: data/levels/campaign.json (level-designer)

```json
{"format": 1, "regions": [
  {"id": "region_1", "name": "Lantern Hill", "levels": ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6"]}
]}
```

Regions and levels in play order. The last level of a region is its boss level. Every level file is listed exactly once, and every listed level exists. How many stars open each region lives in rules.json.

### 2.5 Stats: data/stats/ (game-designer, proposed)

The field lists below are **Assumed** and set in phase 4 from RULES.md. Unknown keys are errors (they catch typos). A missing optional field is 0 or false.

`towers.json`:

```json
{"format": 1, "towers": [
  {"id": "lantern", "name": "Lantern Post", "info": "Quick shots at one creature.",
   "hits": ["ground", "air"], "target": "first",
   "tiers": [
     {"cost": 50, "damage": 6, "reload_ms": 400, "range": 250, "shot_speed": 1200},
     {"cost": 45, "damage": 10, "reload_ms": 400, "range": 275, "shot_speed": 1200}
   ],
   "specs": [
     {"id": "lantern_twin", "name": "Twin Wicks", "info": "Fires twice as often.", "cost": 120,
      "damage": 9, "reload_ms": 200, "range": 275, "shot_speed": 1400},
     {"id": "lantern_far", "name": "Far Glow", "info": "Reaches much further.", "cost": 110,
      "damage": 16, "reload_ms": 500, "range": 400, "shot_speed": 1600}
   ]}
]}
```

- `tiers` has exactly 2 entries (tier 1 build, tier 2 upgrade). `specs` has exactly 2 entries: the two tier 3 choices. `cost` is the price of that step.
- Stat block fields (**Assumed**): `cost`, `damage`, `reload_ms`, `range`, `shot_speed` (0 hits at once), `splash` (radius, 0 for one target), `slow_pct`, `slow_ms`, `pierce` (armor ignored), `boost_pct` (support), plus `id`, `name`, `info` on specs.
- `hits`: `ground`, `air` or both. `target`: the targeting rule, a closed list from RULES.md (**Assumed** `first`: the creature closest to the base).

`enemies.json`:

```json
{"format": 1, "enemies": [
  {"id": "nightling", "name": "Nightling", "info": "Walks the road. Nothing special.",
   "health": 30, "armor": 0, "speed": 100, "flying": false, "gold": 4, "lives": 1}
]}
```

Optional fields (**Assumed**): `shield`, `heal`, `heal_range`, `heal_ms`, `split_into` (enemy id), `split_count`, `force_ms` (forces a gate open after this delay), `boss`.

`rules.json` (**Assumed** keys):

```json
{"format": 1, "sell_refund_pct": 70, "early_call_gold": 10,
 "relaxed_lives_pct": 150, "relaxed_gold_pct": 130,
 "region_stars": [0, 12, 26, 42], "roguelite_stars": 12, "max_waves_active": 2}
```

### 2.6 Effects: twists and cards

Twists, run cards and anything else that changes a rule are lists of effects. Each effect is an object with a `type` from a closed list, and the sim implements each type once. **Assumed** list, set in phase 4:

| type | Fields | Kind | What it does |
|---|---|---|---|
| ban_tower | tower | lasting | The tower cannot be built. |
| add_tower | tower | lasting | The tower can be built (run tower cards). |
| add_gates | count | lasting | More gates in hand. |
| fixed_gates | cells | lasting | Gates already placed on these sockets. They cannot be moved and do not count against `gates`. |
| tower_pct | tower (or `all`), stat (`damage`, `reload`, `range`), pct | lasting | Tower perks. 120 means 20 percent more. |
| kill_gold_pct | pct | lasting | |
| wave_gold_pct | pct | lasting | |
| wave_pct | wave (index, `next` or `last`), pct | lasting | A stronger wave. **Assumed**: health. |
| add_gold | amount | instant | Applied once when added. |
| add_lives | amount | instant | Applied once when added. |

Lasting effects are kept by the battle and saved with it. Instant effects change gold or lives once and are not kept, so a restore never applies them twice.

### 2.7 Segments: data/segments/ (level-designer)

```json
{"format": 1, "id": "mid_split_left_gate", "kind": "middle", "grid": [
  "...#...",
  ".#####.",
  ".G.o.#.",
  ".#####.",
  "...#..."
]}
```

- `kind` is `top`, `middle` or `bottom`. Entrances appear only in top segments and the base only in bottom segments. A segment's row count must equal the run plan's slot for its kind.
- Ports are the columns with a road cell on a segment's top row and on its bottom row. A middle or bottom segment fits under another segment when its top ports equal that segment's bottom ports. The top edge of a top segment and the bottom edge of a bottom segment are the map's own edges, so they need no match.
- data/segments/index.json lists every segment id: `{"format": 1, "segments": ["top_twin", "mid_split_left_gate"]}`. The game loads only listed files, and tests/levels/ checks that every file in the folder is listed.
- A stacked map is checked with `LevelData.check` like any level, so every map a run can build is a valid level.

### 2.8 The run plan: data/runs/run.json (roguelite-engineer, proposed)

**Assumed** shape, set in phase 4 from RULES.md:

```json
{"format": 1,
 "slots": [{"kind": "top", "rows": 4}, {"kind": "middle", "rows": 5}, {"kind": "bottom", "rows": 4}],
 "start_gold": 150, "lives": 20, "gates": 1, "towers": ["lantern", "bakery"],
 "waves": 18, "templates": [], "boss": {}}
```

Slot rows add up to 8 to 13. `templates` and `boss` hold the wave generator's inputs.

### 2.9 Cards: data/cards/cards.json (roguelite-engineer)

```json
{"format": 1, "cards": [
  {"id": "card_mill", "kind": "tower", "name": "Windmill", "text": "Adds the mill for this run.",
   "unlock": "start", "effects": [{"type": "add_tower", "tower": "mill"}]},
  {"id": "card_spare_gate", "kind": "gate", "name": "Spare Gate", "text": "One more gate.",
   "unlock": {"counter": "runs_played", "at": 3}, "effects": [{"type": "add_gates", "count": 1}]},
  {"id": "card_busy_night", "kind": "risk", "name": "Busy Night", "text": "Next wave is stronger. Gain 80 gold.",
   "unlock": "start", "effects": [{"type": "wave_pct", "wave": "next", "pct": 150}, {"type": "add_gold", "amount": 80}]}
]}
```

`kind` is one of `tower`, `perk`, `gate`, `economy`, `risk`. `unlock` is `start` (in the pool from the first run) or a counter threshold. Effects use 2.6.

### 2.10 How data is checked on load

1. `GameData.load_from()` (src/save/) reads every bundled file through `JsonFile.read()`: a size cap before reading, ASCII only, then Godot's JSON parser. Never `load()`, `ResourceLoader`, `str_to_var` or any loader that can make objects.
2. It hands each parsed value to its owner's check, in this order: `Catalog.check` (stats), `LevelData.check` (each level), the campaign list (GameData itself), `SegmentData.check`, `CardCatalog.check`, `RunPlan.check`.
3. Each check verifies: exact keys, types, whole numbers, ranges, id format, that every referenced id exists (towers, enemies, levels, segments, cards), the map rules in 2.2, times that are multiples of 50 ms, and the per wave spawn bound in 9.1.
4. Each check returns every problem as a plain line naming the file and field, for example `r1_l3.json: waves[2].groups[0].count: must be 1 to 200`. An empty list means valid.
5. A bundled file with a problem is a build bug. tests/sim/, tests/levels/ and tests/run/ load every real file and fail on any problem. In the game, if `GameData.problems` is not empty, the App shows one plain message and starts nothing else (**Assumed** text: "This copy of Forkline is damaged. Installing it again should fix it.").

Size caps: a level 64 KB, a segment 16 KB, each stats file 256 KB, cards 256 KB, run.json 64 KB, campaign.json and index.json 16 KB.

## 3. Public classes

Every class below has the listed `class_name`. Fields marked read only are written only inside their own area. Signals are listed with typed arguments; emit only the listed ones. Methods that refuse bad input return a refusal and change nothing. They never clamp, never crash and never `assert` on player input. `push_error` is for programming errors only.

### 3.1 Simulation: src/sim/ (sim-engineer)

#### Timestep and units

| Constant | Value | Meaning |
|---|---|---|
| `Sim.TICKS_PER_SECOND` | 20 | Fixed step of 50 ms of game time. At 3x the sim runs 60 ticks a real second. |
| `Sim.UNIT` | 2000 | Sub-units per cell. A cell center is `cell * UNIT + UNIT / 2`. |

Why these values: a data speed in hundredths of a cell per second equals sub-units per tick exactly (2000 / (100 x 20) = 1), and data times in multiples of 50 ms are whole ticks. So nothing is rounded on load. 20 ticks a second keeps the sim cheap at 3x, and the render draws between ticks, so motion stays smooth at 60 fps.

#### Integer math

- Game state is int, bool, StringName, Vector2i and arrays of those. No float anywhere in src/sim/.
- Positions are Vector2i in sub-units. Distances are compared squared. The only root is `Sim.isqrt()` (integer), used once per flyer at spawn and once per shot fired.
- Percent math is `value * pct / 100`, truncating. Never divide a negative number. The ceilings in 2.3 and 5.6 keep every product far below 2^62.
- No `float`, `sqrt(`, `sin(`, `cos(`, `randf` or float literal in src/sim/. A test in tests/sim/ scans the folder's source for them.

#### Randomness

- Each Battle owns one `RandomNumberGenerator` (Godot's PCG32), seeded once in `Battle.create`. Only `randi()` and `randi_range()` are called on it. Its `state` is saved as a decimal string, because JSON numbers hold only 53 bits exactly. On load the string must match `^-?[0-9]{1,19}$` and survive `str(text.to_int()) == text`.
- A campaign battle's seed is `String(level.id).hash()`, so a level plays the same every time. Run seeds are in 3.4.
- **Assumed**: no battle rule uses chance (the brief has none). The generator exists for any chance rule RULES.md adds.

#### Order

Towers update in cell order (row, then column). Creatures update in id order, which is spawn order. Shots update in id order. Ties go to the lower id or the earlier cell. No rule iterates a Dictionary unless its keys were inserted in one of these orders.

#### Tick order (Assumed, set in phase 4)

1. Spawn due creatures, by wave, then group, then spawn number.
2. Creatures, by id: status timers, heals, gate forcing, then movement. A creature that reaches the base center leaks: lives go down by its `lives`.
3. If a gate was forced open, recompute the distances.
4. Towers, by cell: reload, pick a target, fire.
5. Shots, by id: count down, land, apply damage, splash and slow. A creature at 0 health is defeated: gold, then split children.
6. Remove gone creatures and landed shots. Pay wave clears. Check loss (lives 0 or less) and win (every wave started and cleared).
7. `tick += 1`.

#### Classes

```gdscript
class_name Sim extends RefCounted                      # src/sim/sim.gd: constants and integer helpers
const TICKS_PER_SECOND: int = 20
const MS_PER_TICK: int = 50
const UNIT: int = 2000
const MAP_COLUMNS: int = 7
const MAP_ROWS_MIN: int = 8
const MAP_ROWS_MAX: int = 13
const MAX_ENTRANCES: int = 4
static func isqrt(n: int) -> int                       # floor of the square root; n >= 0
static func center(cell: Vector2i) -> Vector2i         # sub-unit position of a cell center
static func cell_of(pos: Vector2i) -> Vector2i         # the cell holding a sub-unit position
```

```gdscript
class_name Catalog extends RefCounted                  # src/sim/catalog.gd: data/stats/ checked
static func check(towers: Variant, enemies: Variant, rules: Variant) -> PackedStringArray   # every problem; empty when valid
static func from_data(towers: Variant, enemies: Variant, rules: Variant) -> Catalog         # null when check() finds anything
func tower(id: StringName) -> TowerType                # null when unknown
func enemy(id: StringName) -> EnemyType                # null when unknown
func tower_ids() -> Array[StringName]                  # file order
func enemy_ids() -> Array[StringName]                  # file order
var rules: GameRules                                   # read only

class_name TowerType extends RefCounted                # read only; fields converted to ticks and sub-units
var id: StringName
var name: String
var info: String
var hits_ground: bool
var hits_air: bool
var target: StringName
func tier_stats(tier: int, spec: int) -> TowerTier     # tier 1 or 2 with spec -1; tier 3 with spec 0 or 1

class_name TowerTier extends RefCounted                # one stat block, Assumed fields as in 2.5
class_name EnemyType extends RefCounted                # Assumed fields as in 2.5
class_name GameRules extends RefCounted                # rules.json, Assumed fields as in 2.5
```

```gdscript
class_name LevelData extends RefCounted                # src/sim/level_data.gd: one checked level or assembled run map
enum Kind { GROUND, ROAD, SOCKET, SPOT, ENTRANCE, BASE }
const FORMAT: int = 1
static func check(data: Variant, catalog: Catalog) -> PackedStringArray
static func from_data(data: Variant, catalog: Catalog) -> LevelData   # null when check() finds anything
func to_data() -> Dictionary                           # the file shape; from_data(to_data()) gives an equal level
func kind_at(cell: Vector2i) -> Kind                   # GROUND outside the map
var id: StringName                                     # all fields read only
var name: String
var rows: int                                          # columns is always Sim.MAP_COLUMNS
var entrances: Array[Vector2i]                         # index 0 is entrance 1
var base: Vector2i
var sockets: Array[Vector2i]                           # cell order
var spots: Array[Vector2i]                             # cell order
var start_gold: int
var lives: int
var gates: int
var towers: Array[StringName]
var waves: Array[WaveData]
var stars: Array[Dictionary]                           # 2 entries: {"kind": StringName, "value": int}
var hint_text: String                                  # "" for none
var hint_cell: Vector2i                                # (-1, -1) for none
var twist_text: String                                 # "" for none
var twist_effects: Array[Dictionary]

class_name WaveData extends RefCounted                 # read only
var gold: int
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
func distances(closed: Array[Vector2i]) -> PackedInt32Array   # steps to the base per cell (index row * 7 + column), -1 when cut off
func next_step(cell: Vector2i, dist: PackedInt32Array) -> Vector2i   # one step closer; ties: up, right, down, left
func route(entrance: int, dist: PackedInt32Array) -> Array[Vector2i] # entrance (0 based) to base, inclusive; empty when sealed
func seals(closed: Array[Vector2i]) -> bool            # true when any entrance has no open route
```

```gdscript
class_name Modifiers extends RefCounted                # src/sim/modifiers.gd: twists, cards and run perks folded together
static func check_effect(effect: Variant, catalog: Catalog) -> PackedStringArray
static func is_lasting(effect: Dictionary) -> bool
static func from_effects(effects: Array[Dictionary], catalog: Catalog) -> Modifiers   # lasting effects only
var effects: Array[Dictionary]                         # read only; the lasting effects, saved with the battle
# Folded values the rules read (Assumed, set in phase 4): banned and added towers, extra gates,
# fixed gates, tower stat percents by tower and stat, kill and wave gold percents, wave percents by wave.
```

```gdscript
class_name Battle extends RefCounted                   # src/sim/battle.gd: one map being defended
enum Phase { BUILD, WAVE, WON, LOST }
const FORMAT: int = 1
const DONE: StringName = &"done"                       # a command was carried out (not named OK: that would shadow Godot's OK)

# Fixed for the whole battle. Read only.
var level: LevelData
var catalog: Catalog
var map: RoadMap
var relaxed: bool
var mods: Modifiers

# State. Read only outside src/sim/.
var tick: int
var phase: Phase
var waves_started: int                                 # the next wave to start has this index
var gold: int
var lives: int
var gates_in_hand: int
var gates: Array[GateState]                            # cell order
var towers: Array[TowerState]                          # cell order
var enemies: Array[EnemyState]                         # id order
var shots: Array[ShotState]                            # id order
var record_events: bool = true                         # bots set false for speed

static func create(level: LevelData, catalog: Catalog, relaxed: bool, effects: Array[Dictionary], rng_seed: int) -> Battle
func step() -> void                                    # one tick; does nothing unless phase is WAVE
func take_events() -> Array[Dictionary]                # the events since the last call, oldest first

# Player commands. Each returns DONE or a refusal (table below) and a refusal changes nothing.
# Tower commands work in BUILD and WAVE, paused or not. Gate commands work in BUILD only.
func place_tower(cell: Vector2i, type: StringName) -> StringName
func upgrade_tower(cell: Vector2i, spec: int = -1) -> StringName   # spec 0 or 1 only when going from tier 2 to 3
func sell_tower(cell: Vector2i) -> StringName
func place_gate(cell: Vector2i) -> StringName
func move_gate(from: Vector2i, to: Vector2i) -> StringName
func remove_gate(cell: Vector2i) -> StringName
func start_next_wave() -> StringName                   # in BUILD starts the next wave; in WAVE calls it early and pays the bonus
func add_effects(effects: Array[Dictionary]) -> StringName   # run cards; checked first; lasting ones are kept

# Queries. Values in sim units; the UI turns ticks into seconds and sub-units into cells.
func tower_at(cell: Vector2i) -> TowerState            # null for none
func enemy_with_id(id: int) -> EnemyState              # null for none
func build_options(cell: Vector2i) -> Array[Dictionary]   # [{"tower": StringName, "cost": int, "range": int, "affordable": bool}]
func tower_numbers(cell: Vector2i) -> Dictionary       # effective numbers with boosts and modifiers
func upgrade_numbers(cell: Vector2i, spec: int) -> Dictionary   # {"cost": int, "before": Dictionary, "after": Dictionary}
func sell_value(cell: Vector2i) -> int
func enemy_numbers(id: int) -> Dictionary              # health, armor, speed, shield, flying, special rules
func closed_cells() -> Array[Vector2i]                 # gates closed right now
func routes(closed: Array[Vector2i]) -> Array[Dictionary]   # section 4.6
func seals(closed: Array[Vector2i]) -> bool
func wave_count() -> int
func wave_preview(index: int) -> Array[Dictionary]     # [{"enemy": StringName, "count": int, "entrance": int (1 based)}] after modifiers
func next_wave_info() -> Dictionary                    # {"can_start": bool, "early": bool, "bonus": int}
func result() -> Dictionary                            # once WON or LOST: {"won": bool, "stars": int (bits), "lives_left": int, "waves_cleared": int}

# Save (section 5.6). All or nothing.
func to_data() -> Dictionary                           # only bool, int, String, Array and Dictionary values
static func from_data(data: Variant, catalog: Catalog) -> Battle   # null when any field is invalid
```

Star bits in `result()`: 1 for the win, 2 for the second star rule, 4 for the third. A Relaxed win gives only bit 1 (brief 3.9a).

```gdscript
class_name TowerState extends RefCounted               # src/sim/tower_state.gd, read only outside src/sim/
var cell: Vector2i
var type: StringName
var tier: int                                          # 1, 2 or 3
var spec: int                                          # -1 below tier 3, else 0 or 1
var reload: int                                        # ticks until it may fire
var target: int                                        # enemy id, -1 for none
var spent_now: int                                     # gold spent in the current phase: refunded in full
var spent_before: int                                  # gold spent in earlier phases: refunded at sell_refund_pct

class_name EnemyState extends RefCounted               # src/sim/enemy_state.gd
var id: int
var type: StringName
var wave: int
var health: int
var shield: int
var slow_pct: int
var slow_ticks: int
var flying: bool
var from_cell: Vector2i                                # ground: the step being walked
var to_cell: Vector2i
var progress: int                                      # sub-units along the step, 0 to UNIT
var fly_from: Vector2i                                 # flyers: straight line, sub-units
var fly_to: Vector2i
var fly_length: int
var flown: int
var pos: Vector2i                                      # sub-units, after this tick
var prev_pos: Vector2i                                 # sub-units, after the last tick
var action: StringName                                 # &"walk" or &"force" (pushing a gate)
var action_ticks: int

class_name ShotState extends RefCounted                # src/sim/shot_state.gd
var id: int
var tower: Vector2i                                    # the cell it was fired from
var type: StringName                                   # the tower type, for drawing
var target: int                                        # enemy id
var aim: Vector2i                                      # the target's position last tick (kept after it is gone)
var ticks_left: int
var ticks_total: int                                   # flight time, fixed when fired: at least 1
var damage: int                                        # the payload is copied when fired
var splash: int
var slow_pct: int
var slow_ticks: int
var pierce: int

class_name GateState extends RefCounted                # src/sim/gate_state.gd
var cell: Vector2i
var fixed: bool                                        # placed by a twist
var forced_open: bool                                  # opened by a gate breaker this wave
```

Shots are homing with a flight time fixed when fired. A shot always lands on its target. If the target is gone, it lands at `aim`: splash still hits, a single target shot hits nothing (**Assumed**). The render draws a shot between its tower and `aim` from `ticks_left / ticks_total`.

Refunds (**Assumed**): every build phase and every wave is a phase. Gold spent on a tower in the current phase comes back in full; gold spent in an earlier phase comes back at `sell_refund_pct`. At each phase change `spent_now` moves into `spent_before`.

#### Refusals

`&"wrong_phase"`, `&"not_a_spot"`, `&"occupied"`, `&"not_offered"` (tower not available here), `&"too_poor"`, `&"no_tower"`, `&"top_tier"`, `&"pick_spec"`, `&"bad_spec"`, `&"not_a_socket"`, `&"no_gates_left"`, `&"has_gate"`, `&"no_gate"`, `&"fixed_gate"`, `&"would_seal"`, `&"no_more_waves"`, `&"too_many_waves"` (early call over `max_waves_active`), `&"over"` (battle ended), `&"bad_effect"`. The UI turns each into plain feedback. The final list is set in phase 4.

#### Events

Each event is a Dictionary with `"kind"` and the fields below. Commands add events too, so render and audio handle everything in one place. **Assumed** list, set in phase 4.

| kind | Fields |
|---|---|
| `&"wave_started"` | `wave: int`, `early: bool` |
| `&"spawned"` | `id: int`, `enemy: StringName`, `entrance: int` |
| `&"fired"` | `tower: Vector2i`, `shot: int`, `target: int` |
| `&"hit"` | `shot: int`, `target: int`, `pos: Vector2i`, `splash: int` |
| `&"defeated"` | `id: int`, `enemy: StringName`, `pos: Vector2i`, `gold: int` |
| `&"split"` | `id: int`, `children: Array[int]` |
| `&"healed"` | `id: int`, `amount: int` |
| `&"shield_broken"` | `id: int` |
| `&"leaked"` | `id: int`, `enemy: StringName`, `lives: int` |
| `&"gate_forced"` | `cell: Vector2i` |
| `&"wave_cleared"` | `wave: int`, `gold: int` |
| `&"built"`, `&"upgraded"`, `&"sold"` | `cell: Vector2i`, plus `tower`, `tier`, `spec` or `gold` |
| `&"gate_placed"`, `&"gate_removed"` | `cell: Vector2i` |
| `&"won"`, `&"lost"` | none |

### 3.2 How render and UI read the sim and send commands

BattleScreen (ui-engineer) is the only place that steps the sim and drains its events. Each frame:

```gdscript
func _process(delta: float) -> void:
	clock.advance(battle, delta)                       # runs 0 or more whole ticks (BattleClock, 3.6)
	var events: Array[Dictionary] = battle.take_events()
	map_view.sync(clock.alpha())                       # reads battle state, draws between prev_pos and pos
	map_view.play_events(events)                       # puffs, flashes, gate effects
	audio.play_events(events)
	hud.refresh(battle)                                # gold, lives, wave, next wave button
	_handle(events)                                    # wave cleared: save_requested, drafts; won or lost: ended
```

- Render and UI only read `Battle` fields and the state objects. Player actions are command calls, made between frames, so each one lands between two ticks.
- Drawing between ticks: `lerp(Vector2(prev_pos), Vector2(pos), alpha)`, scaled from sub-units to the map's local pixels.
- Inspect panels call the query methods every frame while open. That is cheap.
- On a fold or any resize, only the layout changes (7.5). The Battle and every node that holds state stay.

### 3.3 How the balance bots drive the sim

tools/balance/ (balance-analyst) uses the public API only, with no UI and no class names of its own:

```gdscript
var game: GameData = GameData.load_from("res://data")
var level: LevelData = game.levels[&"r1_l1"]
var battle: Battle = Battle.create(level, game.catalog, false, [], String(level.id).hash())
battle.record_events = false
while battle.phase != Battle.Phase.WON and battle.phase != Battle.Phase.LOST:
	bot.plan(battle)                                   # place, upgrade, sell, gates; the bot's own seeded generator
	battle.start_next_wave()
	while battle.phase == Battle.Phase.WAVE:
		bot.react(battle)                              # optional commands between ticks
		battle.step()
var outcome: Dictionary = battle.result()
```

- A copy for trying a branch: `Battle.from_data(battle.to_data(), game.catalog)`.
- Same seed check: run twice and compare `result()` and `JSON.stringify(battle.to_data())`.
- Runs and the daily: `RunSession.start(...)`, then the same loop, with `session.pick()` at each draft.
- Each bot run prints its seeds, so every number in a docs/balance/ report can be repeated.

### 3.4 Runs, cards and the daily: src/run/ (roguelite-engineer)

Seeds:

- A normal run's seed is one `randi()` from a freshly randomized `RandomNumberGenerator`: the only unseeded draw in the game. It is saved with the run.
- The daily seed is `year * 10000 + month * 100 + day` of the phone's local date (`Time.get_date_dict_from_system()`), for example 20261023. Same on every phone, no network. The daily is always Normal.
- Every other seed is derived: `RunSeeds.derive(run_seed, tag, index)` is `("%d:%s:%d" % [run_seed, tag, index]).hash()`. Tags: `"map"`, `"waves"`, `"battle"`, `"draft"` (index is the draft number). A test pins a few derived values, so an engine change to `String.hash()` is caught.
- So the map, the waves and each draft's offers depend only on the run seed, the pool and the picks so far, never on how the battle went.

Drafts (**Assumed**): each cleared wave except the last owes one draft. Owed drafts open in the next build phase, one at a time. A draft offers 3 different cards drawn from the run's pool with the draft's seed. The pool is fixed at run start: the unlocked cards for a normal run, the starting pool for the daily (**Assumed**, so every player meets the same daily). A pick calls `battle.add_effects()`.

```gdscript
class_name RunSeeds extends RefCounted                 # src/run/run_seeds.gd
static func derive(run_seed: int, tag: String, index: int) -> int
static func daily_seed(date: Dictionary) -> int        # a Time date dictionary
static func day_key(date: Dictionary) -> String        # "2026-10-23"
static func is_day_key(text: String) -> bool           # a real calendar date, 2026-01-01 to 2200-12-31

class_name SegmentData extends RefCounted              # src/run/segment_data.gd
static func check(data: Variant) -> PackedStringArray
static func from_data(data: Variant) -> SegmentData
var id: StringName                                     # read only
var kind: StringName                                   # &"top", &"middle", &"bottom"
var grid: PackedStringArray
var top_ports: int                                     # bit c set when column c has a road on the top row
var bottom_ports: int

class_name RunPlan extends RefCounted                  # src/run/run_plan.gd: data/runs/run.json
static func check(data: Variant, catalog: Catalog, cards: CardCatalog) -> PackedStringArray
static func from_data(data: Variant, catalog: Catalog, cards: CardCatalog) -> RunPlan

class_name CardCatalog extends RefCounted              # src/run/card_catalog.gd: data/cards/cards.json
static func check(data: Variant, catalog: Catalog) -> PackedStringArray
static func from_data(data: Variant, catalog: Catalog) -> CardCatalog
func card(id: StringName) -> Dictionary                # {} when unknown
func ids() -> Array[StringName]
func starting_pool() -> Array[StringName]
func unlocked_by(counters: Dictionary) -> Array[StringName]   # cards whose unlock the counters meet

class_name MapAssembler extends RefCounted             # src/run/map_assembler.gd
static func assemble(run_seed: int, plan: RunPlan, segments: Array[SegmentData], catalog: Catalog) -> LevelData   # map and waves; checked with LevelData.check

class_name RunSession extends RefCounted               # src/run/run_session.gd: one run around its Battle
static func start(run_seed: int, daily: bool, relaxed: bool, pool: Array[StringName], plan: RunPlan,
		segments: Array[SegmentData], cards: CardCatalog, catalog: Catalog) -> RunSession   # a daily ignores relaxed: always Normal
var battle: Battle                                     # read only
var run_seed: int
var daily: bool
var day: String                                        # the daily's day key, "" for a normal run
var pool: Array[StringName]
var picks: Array[StringName]
func draft_open() -> bool                              # a draft is owed and the battle is in BUILD
func offers() -> Array[StringName]                     # the open draft's 3 cards
func pick(card_id: StringName) -> StringName           # Battle.DONE or &"not_offered"; applies the card's effects
func result() -> Dictionary                            # {"won": bool, "waves": int, "lives": int, "picks": int}
func to_data() -> Dictionary                           # without the battle
static func from_data(data: Variant, battle: Battle, plan: RunPlan, cards: CardCatalog) -> RunSession   # null when invalid

class_name Daily extends RefCounted                    # src/run/daily.gd: the daily's rules
static func is_better(a: Dictionary, b: Dictionary) -> bool   # Assumed order: won, then waves, then lives
static func next_streak(streak: int, streak_day: String, today: String) -> int   # Assumed: +1 for the next day, same day keeps, else 1
```

A daily started before midnight keeps its seed and counts for the day it started (**Assumed**).

### 3.5 Files and saves: src/save/ (proposed: roguelite-engineer)

```gdscript
class_name JsonFile extends RefCounted                 # src/save/json_file.gd: the only JSON file reader and writer
## {"status": StringName, "data": Variant}. Status: &"ok", &"missing", &"locked" (exists, cannot be opened)
## or &"bad" (over max_bytes, a NUL byte or a byte of 0x80 or above, or not valid JSON).
static func read(path: String, max_bytes: int) -> Dictionary
static func write_atomic(path: String, data: Dictionary) -> bool   # section 5.3

class_name GameData extends RefCounted                 # src/save/game_data.gd: every bundled data file, checked (2.10)
static func load_from(root: String = "res://data") -> GameData
var problems: PackedStringArray                        # empty when every file is valid
var catalog: Catalog
var campaign: Array[Dictionary]                        # [{"id": StringName, "name": String, "levels": Array[StringName]}]
var levels: Dictionary[StringName, LevelData]
var segments: Array[SegmentData]                       # index.json order
var cards: CardCatalog
var run_plan: RunPlan

class_name SaveStore extends RefCounted                # src/save/save_store.gd: the four save files (section 5)
func _init(dir: String = "user://") -> void            # tests pass a folder under user://tests/
func load_settings() -> Settings
func save_settings(settings: Settings) -> bool
func load_progress() -> Progress
func save_progress(progress: Progress) -> bool
func load_daily() -> DailyRecord
func save_daily(daily: DailyRecord) -> bool
func load_session(game: GameData) -> SavedSession      # null when none; an invalid one is deleted
func save_session(session: SavedSession) -> bool
func delete_session() -> void

class_name Settings extends RefCounted                 # src/save/settings.gd
var sound_on: bool = true
func to_data() -> Dictionary
static func from_data(data: Variant) -> Settings       # any bad field falls back to its default

class_name Progress extends RefCounted                 # src/save/progress.gd
var levels: Dictionary[StringName, int]                # level id to star bits 0 to 7
var twists: Dictionary[StringName, int]                # level id to star bits 0 to 7 for its Twist
var seen: Array[StringName]                            # towers and creatures whose first-sight card was shown
var cards: Array[StringName]                           # cards unlocked into the run pool
var counters: Dictionary[StringName, int]              # closed list of names from RULES.md
func record_level(id: StringName, bits: int, twist: bool) -> void   # keeps the union of earned bits (Assumed)
func star_total() -> int                               # star marks over campaign levels, Twists not counted (Assumed)
func mark_seen(id: StringName) -> void
func add_counter(name: StringName, amount: int) -> void   # saturates at the ceiling, so a save never fails its own check
func to_data() -> Dictionary
static func from_data(data: Variant) -> Progress

class_name DailyRecord extends RefCounted              # src/save/daily_record.gd
var day: String                                        # "" or the day key of `best`
var best: Dictionary                                   # that day's best RunSession.result(), {} for none
var streak: int
var streak_day: String
func record_finish(day: String, result: Dictionary) -> void   # uses Daily.is_better and Daily.next_streak
func to_data() -> Dictionary
static func from_data(data: Variant) -> DailyRecord

class_name SavedSession extends RefCounted             # src/save/saved_session.gd: the one level or run in progress
var kind: StringName                                   # &"level" or &"run" (a daily is a run with run.daily true)
var level_id: StringName                               # campaign level id; &"" for runs
var twist: bool
var battle: Battle
var run: RunSession                                    # null for campaign levels
```

### 3.6 Screens and app glue: src/ui/, scenes/ui/ (ui-engineer)

```gdscript
class_name App extends Control                         # src/ui/app.gd, root of scenes/ui/app.tscn
## Creates GameData, SaveStore, Settings, Progress, DailyRecord and AudioService once and passes them down with setup().
## Routes between screens, saves on lifecycle notifications, handles the back button.

class_name Layout extends RefCounted                   # src/ui/layout.gd (section 7)
const LANDSCAPE_BELOW: float = 1.5
const MIN_TOUCH: float = 160.0                         # logical px; at least 48 dp on every phone in 7.4
static func is_landscape(window_size: Vector2) -> bool # height < 1.5 x width
static func safe_rect(viewport: Viewport) -> Rect2     # the display safe area in viewport coordinates

class_name BattleClock extends RefCounted              # src/ui/battle_clock.gd: real time to whole ticks
var speed: int = 1                                     # 1, 2 or 3
var paused: bool = false
const MAX_FRAME_SECONDS: float = 0.25                  # a long frame or a return from the background never bursts
const MAX_TICKS_PER_FRAME: int = 6
func advance(battle: Battle, delta: float) -> int      # ticks run; none while paused or outside WAVE
func alpha() -> float                                  # 0 to 1, how far between the last tick and the next
func reset() -> void                                   # clears the leftover time

class_name BattleScreen extends Control                # src/ui/battle_screen.gd: map, HUD, panels, input
signal save_requested()                                # start of a build phase, a card pick, Pause opened
signal ended(result: Dictionary)                       # WON or LOST
signal left()                                          # the player left to the menu; the session stays saved
func setup(battle: Battle, run: RunSession, audio: AudioService, progress: Progress) -> void   # run is null for campaign levels
func apply_layout(window_size: Vector2) -> void        # test hook too (7.5)
func pause() -> void                                   # opens Pause; used on focus loss
func is_paused() -> bool

class_name Links extends RefCounted                    # src/ui/links.gd (section 8)
```

The other screens are used only inside src/ui/, so their signals can change without a contract change: FrontDoor, ModeScreen (Continue card, Campaign, Roguelite, Daily), LevelSelect, LevelCard (star rules, Normal or Relaxed, Twist when unlocked), RunCard (difficulty for a run; the daily is always Normal), DraftPanel, WavePreview, InfoCard (first sight), PausePanel (Resume, Info, Settings, leave with a confirm, the quiet coffee row), SettingsPanel (sound, About), InfoScreen, AboutScreen, EndPanel, ConfirmDialog.

App flow:

1. **Launch.** `GameData.load_from()`. If it has problems, show the damaged message and stop. Load settings, progress, daily and the session (an invalid session is deleted). Set the theme. Show the front door. Set `get_tree().quit_on_go_back = false`.
2. **Play** opens ModeScreen. When a session was loaded, a Continue card on top resumes it in one tap. Starting anything new while a session is saved asks for a confirm, then deletes it (**Assumed**, one saved session at a time).
3. **Battle.** A campaign level: `Battle.create(level, catalog, relaxed, effects, String(level.id).hash())`, where `effects` is the level's `twist_effects` when playing its Twist and empty otherwise. A run or the daily: `RunSession.start(...)`. Then `BattleScreen.setup()`. A resumed session opens paused.
4. **Saving.** On `save_requested` the App saves the session. On `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_WM_CLOSE_REQUEST` while a battle is in progress, it first calls `battle_screen.pause()` if a wave is running, then saves the session. Progress and daily save when they change.
5. **End.** On `ended`: record stars or the run result, update counters and unlocked cards, update the daily record for a daily, delete the session, save, show EndPanel.
6. **Back button.** Close the top panel or dialog first. In a battle, open Pause. On the front door, save and quit.
7. **Resize.** The App connects `get_tree().root.size_changed` and calls `apply_layout()` on the live screen (7.5).
8. **Debug builds** (`OS.is_debug_build()`) add a `PerfProbe` (3.7). Release builds never do.

### 3.7 Render: src/render/, shaders/ (render-engineer)

```gdscript
class_name MapView extends Node2D                      # src/render/map_view.gd
const CELL: float = 128.0                              # local px per cell; fit() scales the node
func setup(battle: Battle) -> void                     # builds the static map layer and entity nodes
func fit(rect: Rect2) -> void                          # rect in the parent's coordinates; position and scale so the map fills it
func cell_at(global_point: Vector2) -> Vector2i        # a global canvas position to a cell; (-1, -1) outside the map
func enemy_at(global_point: Vector2) -> int            # the nearest creature within reach of a finger, -1 for none
func sync(alpha: float) -> void                        # every frame: add, move and remove entity nodes from battle state
func play_events(events: Array[Dictionary]) -> void
func show_routes(routes: Array[Dictionary], refused: bool) -> void   # [] hides the lines
func show_range(cell: Vector2i, range_units: int) -> void            # (-1, -1) hides it
func show_selection(cell: Vector2i) -> void
func show_hint(cell: Vector2i) -> void

class_name PerfProbe extends Node                      # src/render/perf_probe.gd: debug builds only (section 9)
```

MapView draws in its own local space, where a cell is `CELL` pixels. `fit()` changes only the node's position and scale, so a fold re-fits one transform and every child, including particles in flight, keeps its place.

### 3.8 Audio: src/audio/ (audio-engineer)

```gdscript
class_name AudioService extends Node                   # src/audio/audio_service.gd
func set_enabled(on: bool) -> void
func play_events(events: Array[Dictionary]) -> void    # battle events to sounds, with caps (section 9)
func play_ui(sound: StringName) -> void                # &"tap", &"build", &"refuse", ...
func set_music(track: StringName) -> void              # &"menu", &"battle", or &"" for silence
```

### 3.9 Theme: src/theme/ (art-director)

Finalized in phase 4 with the design system. The other areas expect:

```gdscript
class_name Palette extends RefCounted                  # color tokens
class_name UiTheme extends RefCounted                  # static func build() -> Theme
class_name Silhouettes extends RefCounted              # draws every tower and creature in the catalog
static func draw_tower(canvas: CanvasItem, type: StringName, tier: int, spec: int, center: Vector2, size: float) -> void
static func draw_enemy(canvas: CanvasItem, type: StringName, center: Vector2, size: float, frame: int) -> void
class_name Wordmark extends Control
class_name IconArt extends RefCounted                  # static func draw(size: int) -> Image, for tools/icon/ and tools/store/
```

## 4. Routing

### 4.1 The road graph

Nodes are road cells (`#`, `G`, `1` to `4`, `B`). Edges join orthogonal neighbors, and every edge is one step long. `RoadMap` builds this once per battle.

### 4.2 Gates and sockets

- A gate sits on a socket and closes it to ground creatures. Flyers ignore roads and gates.
- Gates in hand: the level's `gates`, plus `add_gates` effects, minus gates placed. Fixed gates from a twist do not count and cannot be moved or removed.
- Gate commands work only in BUILD. During a wave gates are locked. A gate breaker can force one open (4.5).

### 4.3 The shortest open route and the tie break

- `RoadMap.distances(closed)` runs one breadth-first search from the base over open road cells. The result is the number of steps to the base for each cell, or -1 when cut off.
- A ground creature on a cell steps to the neighbor whose distance is one less. When neighbors tie, it takes the first in this fixed order: **up, right, down, left** (row - 1, column + 1, row + 1, column - 1).
- A creature always finishes the step it is on, then chooses again. When the distances change mid-wave, creatures take the new shortest route from where they are, even if that turns them around.
- Distances are recomputed only when the closed set changes: a gate command in BUILD, or a gate forced open. One recompute is a search over at most 91 cells.

### 4.4 The seal check

- A closed set seals when any entrance has distance -1. `place_gate` and `move_gate` refuse such a set with `&"would_seal"` and change nothing (**Assumed**: every entrance must keep an open route).
- In BUILD no creature is on the map, so checking the entrances is enough. **Assumed**: if a later rule lets gates close mid-wave, the check also covers every cell with a ground creature on it.
- Level files and assembled run maps must have an open route from every entrance with every socket open, and with only the fixed gates closed.

### 4.5 The gate breaker and flyers

- **Assumed** (RULES.md decides): a creature with `force_ms` routes on the distances with every socket open. When its next cell holds a closed gate, it stops at its cell center, waits `force_ms`, then forces the gate open (`gate_forced`). The gate stays open until the next build phase, then closes again where it was. Distances are recomputed at once and every creature follows the new field.
- A flyer flies straight from its entrance's cell center to the base's cell center. Its line length comes from `Sim.isqrt` once at spawn. Its position is `fly_from + (fly_to - fly_from) * flown / fly_length`, in integers.
- "Closest to the base" for targeting: a ground creature's remaining distance is `dist[to_cell] * UNIT + (UNIT - progress)`, using the distances it walks on (the gate breaker's own field for a gate breaker). A flyer's is `fly_length - flown`.

### 4.6 Route line data

- `Battle.routes(closed)` returns one entry per entrance, in entrance order: `{"entrance": int (1 based), "cells": Array[Vector2i]}`, from the entrance to the base. `cells` is empty when that entrance is sealed.
- It follows the same step rule as creatures, so the line shows exactly where they will go. All ground creatures from one entrance share one route, so one line per entrance is complete.
- While the player places or drags a gate, the UI calls `routes()` with the would-be closed set each time the finger reaches another socket, and passes the result to `MapView.show_routes(routes, refused)`. When any entry is empty, the placement would be refused: the line shows its refused style and the reason shows. Otherwise the UI shows `routes(closed_cells())`, which also updates when a gate is forced open.
- Ties at forks are allowed, but a hidden tie surprises players. tests/levels/ lists every fork where branches tie for some gate set the player can make, so the level designer can avoid or accept each one.

## 5. Save format

### 5.1 Files

All in `user://` (the app's private storage, removed on uninstall). Each may have a `.tmp` and a `.bak` beside it.

| File | Holds | Written | Size cap |
|---|---|---|---|
| settings.json | sound on or off | when the setting changes | 4 KB |
| progress.json | star bits per level and Twist, first-sight ids, unlocked cards, counters | when any of it changes: a level or run ends, a first-sight card shows, a card unlocks | 64 KB |
| daily.json | the day's best daily result and the streak | when a daily run ends (**Assumed**) | 16 KB |
| session.json | the one level or run in progress, the exact state | at the start of every build phase (after any round), after a card pick, when Pause opens, on focus loss, app pause and close request, and when leaving the battle. Deleted when the level or run ends or is abandoned. | 1 MB |

Writes are synchronous on the main thread. The largest file is under 100 KB in the biggest wave, a few milliseconds to write. A write whose text equals the last text written to that file is skipped.

### 5.2 Reading

1. A missing file means defaults (or no session).
2. A file that exists but cannot be opened is **locked**. Its defaults are used in memory and nothing in this launch writes, renames or deletes it or its `.tmp` or `.bak`, because it may hold good data.
3. A file over its cap is refused before any of it is read.
4. A NUL byte or any byte of 0x80 or above is refused before parsing. Every saved string is an id, a day key or a number in a string, so the files are plain ASCII.
5. The text goes through `JSON.new().parse()`. A parse error means invalid. Godot's parser refuses nesting past its limit cleanly (checked with 4.7.2: 600 levels parse, 2,000 fail with an error, nothing crashes). Never `str_to_var`, `bytes_to_var`, `FileAccess.get_var`, `ConfigFile`, `load()`, `ResourceLoader` or anything that can make objects from file data.
6. Then every field is checked for type, range and shape.
7. A file whose `format` is higher than this build knows is treated like a locked file, so a newer save is never overwritten by an older build. The session is the exception: it is deleted.

### 5.3 Writing (atomic)

1. Build the dictionary with `to_data()`: only bool, int, String, Array and Dictionary values. Vector2i becomes `[x, y]`, StringName becomes String, the random state becomes a decimal string.
2. `JSON.stringify(data)` (sorted keys). Refuse to write text that is not plain ASCII.
3. Write the text to `<name>.tmp`, flush, close. Read it back and compare. On any difference, delete the `.tmp` and return false.
4. If `<name>` holds exactly the text this store last wrote or loaded as valid, rename it to `<name>.bak`. If that rename fails, carry on without a fresh backup.
5. Rename `<name>.tmp` to `<name>`.
6. **A failed rename** returns false and leaves the `.tmp` in place. It holds the newest complete save, and the next load uses it. The next write tries again. On Windows, Godot's rename removes the target, then moves the file in: it fails while another program holds the target (checked with 4.7.2: the old file stays, the `.tmp` stays), and SumUp saw it fail half way while the temp file was held (the target gone, the `.tmp` kept). On Android, Godot uses POSIX rename, which replaces the file in one step. In every case a kill at any moment leaves a complete newest save in `.tmp` or `<name>`, plus the `.bak`.
7. The App logs a failed save once per launch, not every time. No error shows to the player.

### 5.4 Loading order

Try a valid `<name>.tmp` first (it is always the newest attempt); if valid, rename it into place. Then a valid `<name>`. Then a valid `<name>.bak` (one save behind). A `.tmp` that fails its check is deleted. For settings, progress and daily, "valid" means a JSON object with a known `format`, and any bad field inside falls back to its own default. For the session, "valid" means every check in 5.6 passes. When no session copy passes, all three are deleted (`.tmp`, then `.bak`, then the file), so a bad session never comes back.

### 5.5 Shapes and ceilings

Ceilings are far above anything a real player reaches. Counters saturate at their ceiling, so the game never writes a value its own check refuses.

```json
{"format": 1, "sound": true}
```

```json
{"format": 1,
 "levels": {"r1_l1": 7, "r1_l2": 3},
 "twists": {"r1_l1": 1},
 "seen": ["nightling", "lantern"],
 "cards": ["card_spare_gate"],
 "counters": {"runs_played": 4, "runs_won": 1, "waves_cleared": 61}}
```

- `levels`, `twists`: at most 512 entries each, keys in id form, values 0 to 7. Unknown but well-formed level ids are kept and ignored, so a later version's progress survives.
- `seen`: at most 512 ids. `cards`: at most 512 ids. No repeats.
- `counters`: only the names in RULES.md (**Assumed**: `runs_played`, `runs_won`, `waves_cleared`), each 0 to 1,000,000,000.

```json
{"format": 1, "day": "2026-10-23", "best": {"won": false, "waves": 12, "lives": 0, "picks": 11},
 "streak": 3, "streak_day": "2026-10-23"}
```

- `day`, `streak_day`: `""` or a real calendar date from 2026-01-01 to 2200-12-31. `best`: `{}` or the result shape, numbers 0 to 1000. `streak`: 0 to 100,000.

```json
{"format": 1, "kind": "run", "level_id": "", "twist": false,
 "battle": {},
 "run": {"seed": 1840331, "daily": false, "day": "",
         "pool": ["card_mill", "card_busy_night"], "picks": ["card_mill"], "drafts_owed": 0, "drafts_done": 1}}
```

`kind` is `level` or `run`. `battle` holds `Battle.to_data()` (5.6), including the difficulty. `run` is null for a campaign level.

### 5.6 The saved battle

`Battle.to_data()` (**Assumed** keys, set in phase 4):

```json
{"format": 1,
 "level": {"...": "LevelData.to_data(), the file shape of 2.3"},
 "relaxed": false,
 "effects": [{"type": "ban_tower", "tower": "bakery"}],
 "rng": "8121734412345678901",
 "tick": 4210, "phase": "wave", "waves_started": 4,
 "active": [{"wave": 3, "groups": [[5, 4260], [0, 4300]]}],
 "gold": 230, "lives": 17, "gates_in_hand": 0,
 "gates": [{"cell": [1, 3], "fixed": false, "open": false}],
 "towers": [{"cell": [3, 3], "type": "lantern", "tier": 2, "spec": -1, "reload": 3, "target": 41, "now": 0, "before": 95}],
 "enemies": [{"id": 41, "type": "nightling", "wave": 3, "health": 22, "shield": 0, "slow": [30, 12],
              "from": [5, 4], "to": [5, 5], "at": 1450, "action": "walk", "action_ticks": 0}],
 "shots": [{"id": 77, "tower": [3, 3], "type": "lantern", "target": 41, "aim": [11000, 9000],
            "left": 2, "total": 4, "damage": 10, "splash": 0, "slow": [0, 0], "pierce": 0}],
 "next_id": 120,
 "stats": {"lives_lost": 3, "towers_built": 5}}
```

`active` lists each running wave with, per group, the number spawned and the next spawn tick. `stats` holds what the star rules need. Positions such as `pos` and `prev_pos` and the distances are rebuilt on load, not saved.

Checks in `Battle.from_data` (sim-engineer), all or nothing:

| Field | Rule |
|---|---|
| level | passes `LevelData.check` |
| effects | at most 64, each passes `Modifiers.check_effect` |
| rng | decimal string, round trip exact |
| tick | 0 to 1,000,000,000 |
| phase | `build`, `wave`, `won` or `lost`; a saved session is only ever `build` or `wave` |
| waves_started, active | within the level's wave count; group counts within each group |
| gold | 0 to 1,000,000,000 |
| lives | 0 to 1,000,000 |
| gates | at most the socket count; each on a socket; the closed set does not seal |
| towers | at most the spot count; each on a free spot; known type; tier 1 to 3; spec matches tier |
| enemies, shots | at most 4,000 each; ids 0 to 2^31, unique, below `next_id`; known types; health 1 to 1,000,000,000; cells on road and joined; `at` 0 to UNIT; flyer numbers inside the map |
| all numbers | whole, finite, in range; then converted to int |

`RunSession.from_data` checks the run fields the same way: known card ids, at most 64 picks, `drafts_owed` 0 to the wave count, `day` a day key or `""`.

## 6. Resume after the app is killed (brief 3.10)

Leaving the app always saves (focus loss and app pause come first, even when the app is later swiped away or killed in the background). The question is what that save holds when a wave is running. In both options the game reopens paused.

| | A. The exact moment | B. The start of the current wave |
|---|---|---|
| What is saved mid-wave | Everything: creatures, shots, spawn timers, towers, gates, gold, lives, the random state. | The battle as it was when the current wave started. Mid-wave changes are not saved. |
| What a kill loses | Nothing since the last focus loss. | Up to a whole wave, including towers built, upgrades, sales and gold earned during it. |
| Code | `Battle.to_data()` and `from_data()` for every field, with checks (5.6). | The same for the build phase state only, plus a copy of that state kept in memory through each wave. |
| Tests | Snapshot at many ticks on real levels with every creature type, restore, play on, and compare with an uninterrupted run. | Snapshot and restore of build phase states. |
| Save size | Up to about 100 KB in the largest wave. | About 10 KB. |
| Check surface | More fields to check (creatures, shots, timers). | Fewer fields. |
| Ways to cheat | None. Killing the app undoes nothing. | Kill the app to undo a bad wave: dodge a run loss (brief 3.7, "losing ends the run") and retry the daily for a better best. Stopping that needs extra rules. |
| Feel | Comes back exactly where the player left. | Comes back earlier than where the player left, with recent towers gone. |

Most of A's cost exists anyway. The sim-engineer's brief already requires snapshot and restore with an identical result, and the bots copy battles to try branches. A missed field is the main danger; the snapshot, restore and continue test catches it as long as the test levels use every creature, tower and effect.

**Recommendation: A, the exact moment.** Bart decides. The rest of this document assumes A; with B, section 5.6 shrinks to the build phase fields.

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
- The lock is not a guarantee. Split screen, pop-up windows, the user's aspect ratio setting, and future Android or Samsung changes can hand the game any window shape. So the layout never reads the orientation. It reads the window size, on every change.
- Folding mid-wave is a window resize inside the same running game. Nothing is rebuilt.

### 7.4 The layout rule and the map size

`Layout.is_landscape(size)` is true when the window's height is less than 1.5 times its width. It is a pure function of the window size, checked on every resize. No setting.

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

The map never rotates. The same 7 column grid shows in both layouts; only the HUD moves.

- **Portrait:** the map at full width, the HUD above and below it. With 13 rows, the HUD gets at most 590 logical px of height in total, outside the safe insets.
- **Landscape:** the map at full height inside the safe area, one side panel at least 720 logical px wide for the HUD, the build panel and the wave preview (as in the theme slice).
- The project keeps its 1080 x 2400 base with `canvas_items` stretch and `expand`, so the cover screen is 1080 x 2767 logical px and the inner screen 1998 x 2400.

Touch size, with SumUp's measured densities and the same base viewport:

| Screen | Logical px per dp | 160 px (`MIN_TOUCH`) | Map cell, 7 columns | 8 columns | 9 columns |
|---|---|---|---|---|---|
| Fold5 cover | 3.14 | 51 dp | 154 px, 49 dp | 43 dp | 38 dp |
| 20:9 phone at 2.625 | 2.63 | 61 dp | height limited: 127 px, 48 dp at 13 rows | | |
| Fold5 inner, landscape | 2.89 | 55 dp | height limited: about 167 px, 58 dp | | |
| 16:9 phone at 2.625 | 3.28 | 49 dp | height limited: 127 px, 39 dp at 13 rows | | |

So 7 columns is the widest map whose cells stay at 48 dp on the Fold5 cover (**Assumed**, open question 2). The table assumes the full 590 px portrait HUD and the measured insets: about 170 logical px on the cover and on phones, about 230 on the inner screen with its taskbar. Old 16:9 phones fall short with 13 rows (39 dp); a smaller HUD or fewer rows helps there. Taps on the map only select a cell; building, upgrading and selling happen on 48 dp buttons in the build panel.

### 7.5 Folding and unfolding mid-wave

1. Android resizes the window. Godot keeps running (7.2).
2. The App gets `size_changed` and calls `BattleScreen.apply_layout(size)`.
3. `apply_layout` picks the layout, moves the HUD parts into the portrait or landscape container and calls `map_view.fit(map_rect)`. It never frees a node that holds state and never touches the Battle. The selection, an open panel, the speed and the pause state stay. A touch in progress (a gate drag, a held button) is cancelled.
4. If the fold comes with a focus loss (Samsung can ask whether to continue on the cover screen), the game pauses and saves as for any focus loss.
5. If Android ever recreates the activity anyway, the engine restarts and the exact-moment save resumes the battle (section 6).

### 7.6 Settings for the DM and the release engineer

project.godot (DM):

- Keep `display/window/handheld/orientation=1` (portrait).
- Keep `display/window/size/resizable` at its default, true. Never set it false: that would make the game non-resizable, and large screens may then show it in compatibility mode or offer a restart on fold.
- Keep the 1080 x 2400 base, `canvas_items` stretch and `expand`.
- Nothing else is needed for orientation. `application/run/max_fps` waits for the measurement in section 9. Set `input_devices/pointing/emulate_touch_from_mouse=true` only if the ui-engineer asks for it to test map touches on Windows.

export_presets.cfg (release-engineer):

- `package/app_category=2` (Game, the default).
- `screen/immersive_mode=true`, `screen/edge_to_edge=false` (defaults). The UI uses the safe area. QA checks the cover screen's camera cutout and the inner screen's taskbar inset.
- `screen/support_small`, `support_normal`, `support_large`, `support_xlarge` all true.
- `gradle_build/target_sdk` and `min_sdk` empty (36 and 24).
- `user_data_backup/allow=false` and `package/retain_data_on_uninstall=false`, so saves stay on the phone and go with an uninstall (playbook section 4).
- `include_filter="LICENSE, NOTICE, data/*"` so every data JSON ships, and `exclude_filter="tests/*, tools/*, docs/*, prototypes/*"`.
- No permissions.
- The APK check reads the built manifest with aapt2 and confirms: `targetSdkVersion` 36, `screenOrientation` 1, `resizeableActivity` true, `appCategory` game, `configChanges` includes 0x1d80 (orientation, screenLayout, screenSize, smallestScreenSize, density), no `uses-permission`, and every data file present.

### 7.7 Not planned: rotating on the unfolded phone

If Bart wants the game to turn when he turns the unfolded phone, the App can call `DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)` when the window's smallest side is 600 dp or more and `SCREEN_PORTRAIT` below that, on each resize. Games are exempt from the Android 16 and 17 override, so the request is honored. Open question 5.

### 7.8 Sources

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
- Tests set `Links.opener` to a recorder in `before_each()` and reset it to `Callable()` in `after_each()`. A lambda left in a static var crashed Updraft's engine on quit.

## 9. Performance budget

Target: 60 fps on the Fold5 (Snapdragon 8 Gen 2), on both screens, through the largest wave of the game at 3x.

### 9.1 Entity ceilings

| Thing | Budget | Held by |
|---|---|---|
| Live creatures at once, split children included | 200 | Level checks: one wave spawns at most 120 creatures counting split children; at most `max_waves_active` (2) waves run at once. Bots report the real peak. |
| Towers | 24 | Build spots per map (2.2). |
| Shots in flight | 150 | Follows from towers and flight times. Bots report the peak. |
| Particles alive | 400 | Pooled emitters, at most 24, at most 16 particles per puff. |
| Sound voices | 12 | At most 3 of the same sound at once. |
| Draw calls per frame | about 200 | Measured. |

### 9.2 Time per frame on the Fold5 (16.7 ms)

- Sim: at most 2 ms per frame at 3x (one tick per frame at 60 fps), with 200 live creatures. On the dev PC, headless: at most 0.5 ms per tick.
- Render and UI scripts (`sync`, events, HUD): at most 3 ms.
- GPU: at most 8 ms.
- The 99th percentile frame over the whole wave: at most 20 ms.

### 9.3 Draw approach

- The static map (ground, roads, spots, scenery) is drawn once into its own layer and redrawn only when gates change.
- One Node2D per tower and per creature, drawn once with `Silhouettes` and redrawn only when its look changes (tier, slowed, shield). Each frame only its position changes. Nodes are pooled and reused.
- Health bars for hurt creatures and all shots are drawn by one overlay node each, redrawn every frame.
- Sparkle puffs use pooled one-shot `CPUParticles2D` emitters (simulated in C++, predictable in the Compatibility renderer).
- No `Light2D`, no screen-reading shaders (`SCREEN_TEXTURE`, `BackBufferCopy`), no full-screen transparent layers beyond one sky gradient. Keep shared materials, so the Compatibility renderer can batch.
- Inside the sim: each tower keeps the list of road cells in its range, rebuilt only when towers change; creatures are bucketed by cell each tick, so targeting checks nearby creatures, not all of them. Flyers, being few, are checked directly.

### 9.4 How to measure

1. **Sim, headless:** a benchmark tool in tools/balance/ plays each level's largest wave with a bot's build and prints the mean and 99th percentile ms per tick and the peak live creatures.
2. **On the phone:** the same tool writes a session file through `SaveStore` just before the largest wave starts. Push it into a debug build's files folder: `adb push session.json /data/local/tmp/`, then `adb shell run-as io.github.bartbasi.forkline cp /data/local/tmp/session.json files/session.json`. Open the game, tap Continue, set 3x. This uses the normal resume path, so the test is the real game.
3. **PerfProbe** (debug builds only) prints one line every 2 seconds during a wave: fps, 99th percentile frame ms, process ms, draw calls, objects, live creatures. Read it with `adb logcat -s godot`. Measure on the cover screen, on the inner screen, and while folding mid-wave.
4. Godot renders at the display rate by default (`application/run/max_fps=0`), which can mean 120 fps on the Fold5. The render-engineer measures both, and the DM sets `application/run/max_fps=60` if 120 costs too much heat or paces badly.
5. The render-engineer reports the numbers and the device state (screen, speed, wave) in its report.

## 10. Tests per owner

General rules (CLAUDE.md "Writing tests" applies):

- Files are `tests/<area>/test_*.gd` and extend `res://tests/base_test.gd`. Fixtures live in `tests/<area>/fixtures/`.
- Every random generator is seeded. Save tests use a folder under `user://tests/<area>/`, removed in `after_each()`, never the real save files.
- Nodes a test adds to the tree (through `Engine.get_main_loop() as SceneTree`) are freed in the same test.
- Run one area with `godot --headless --path . --script res://tests/run_tests.gd -- --only=sim`.

| Folder | Owner | Covers |
|---|---|---|
| tests/project/ | DM | Source headers, LICENSE MD5, NOTICE lines. Suggested: no network class names and no forbidden loaders (`str_to_var`, `bytes_to_var`, `get_var`, `ConfigFile`, `ResourceLoader`, `load(` on data) anywhere in src/. |
| tests/sim/ | sim-engineer | Catalog and LevelData checks with good and hostile fixtures; every map rule; distances, the tie break, the seal check, route lines; every tower and creature rule; economy, refunds, the early call; lives, win, loss and star bits; same seed and commands give the same `to_data()`; snapshot, restore and continue equals uninterrupted, at many ticks, on levels using every creature and effect; hostile battle data (wrong types, out of range, huge arrays, bad references) gives null; the real stat files load; no float math in src/sim/. |
| tests/levels/ | level-designer | Every file in data/levels/ and data/segments/ loads through `GameData` with no problems and is listed; every entrance has an open route with no gates; only towers and creatures introduced by then; never two new things in one wave; the spawn bound in 9.1; Twist validity; tie report (4.6); ASCII only. |
| tests/run/ | roguelite-engineer | Card and run plan checks; pool and unlocks; same seed gives the same map, waves and offers; every pair of joinable segments assembles into a valid level; daily seed from a date; derived seeds pinned; streak and best rules; run save and restore. |
| tests/save/ | roguelite-engineer (proposed) | Atomic write; failed rename keeps the newest save in `.tmp`; `.tmp` wins on load; `.bak` fallback; locked file never overwritten; newer format left alone; hostile files (empty, truncated, huge, NUL, high bytes, wrong types, out of range, deep nesting, numbers past ceilings); defaults per field; counters saturate; session round trip; an invalid session is deleted. |
| tests/ui/ | ui-engineer | `Layout.is_landscape` table (7.4); `apply_layout` mid-wave keeps `battle.to_data()` identical and every state node alive; `BattleClock` tick counts at 1x, 2x, 3x, pause and the burst cap; each link button hands its constant to the opener exactly once; feedback URL encoding (a model name with `&cc=` stays in the body); touch targets at least `MIN_TOUCH` in both layouts at the Fold5 sizes; focus loss writes the session and pauses; back button order; Continue card. |
| tests/render/ | render-engineer (proposed) | MapView sets up for every real level headless; `cell_at` and `fit` round trip at several sizes; `sync` adds and frees nodes as creatures spawn and go, with no leak after a full wave. |
| tests/audio/ | audio-engineer (proposed) | Every sound renders non-silent and never clips; voice caps hold; disabled means silent. |
| tests/theme/ | art-director (proposed) | Text contrast of every token pair at least 4.5:1; `Silhouettes` draws every tower id, tier and spec and every creature id in the catalog. |

The balance bots in tools/balance/ are tools, not tests. They run on demand and write dated reports to docs/balance/.

## 11. Assumed until RULES.md is approved

Each item has a data shape that can hold the final rule. Phase 4 settles them.

1. The stat block fields, the creature special fields and the rules.json keys (2.5).
2. The effect types for twists and cards, and which are lasting or instant (2.6). Twists change one rule, so one effect each.
3. The targeting rules (`first`: closest to the base by route).
4. The tick order (3.1).
5. Refunds: full for gold spent in the current phase, `sell_refund_pct` for earlier phases; each build phase and each wave is a phase.
6. The early call: allowed during a wave, starts the next wave at once, pays a bonus, at most 2 waves running at once.
7. Wave clear gold set per wave in the level file.
8. Star rule kinds; stars stored as bits; earned marks kept across plays (the union); Relaxed earns only the win star.
9. The gate breaker routes as if every gate were open, stops at the gate, forces it open after `force_ms`, and the gate closes again at the next build phase.
10. Flyers fly straight from their entrance to the base.
11. A placement seals when any entrance loses its last open route.
12. Homing shots with a fixed flight time; a shot whose target is gone lands where it aimed.
13. No chance in battle rules.
14. Runs: one map per run from one top, one middle and one bottom segment; waves made at the start; one draft owed per cleared wave, opened in the next build phase.
15. The daily uses the starting card pool, counts for the day it started, and the streak counts days with a finished daily.
16. Maps are 7 columns by 8 to 13 rows; entrances sit on the map edge.
17. One saved session at a time; starting something new asks before ending it.
18. The difficulty choice is not remembered between levels.
19. A tower counts as unlocked once the player has played a level that offers it. This is worked out from progress and the campaign order, so nothing extra is saved.

## 12. Open questions for Bart and the DM

1. **Resume (Bart):** the exact moment (recommended) or the start of the current wave? Section 6.
2. **Map width (Bart and the game designer):** 7 columns keeps map cells at 48 dp on the Fold5 cover. 8 columns gives 43 dp there and 9 gives 38 dp. Is a 7 x 13 grid at most acceptable for the puzzles, or is a smaller touch size on the cover acceptable for wider maps?
3. **Saved sessions (Bart):** one at a time, as the single Continue card suggests (starting a level while a run is saved ends the run after a confirm), or one per mode, so a 20 minute run is never lost to a quick campaign level?
4. **Owners (DM):** src/save/ and tests/save/ to the roguelite-engineer (or the sim-engineer); data/stats/ to the game designer; data/runs/ to the roguelite-engineer; tools/icon/, icons/ and tests/theme/ to the art director; tests/render/ and tests/audio/ to their areas; docs/ASSETS.md stays with the DM. The agent files of the game designer, roguelite-engineer, art director, render-engineer and audio-engineer need the new paths.
5. **Rotation (Bart):** on the unfolded phone the game keeps its portrait lock and uses the landscape layout. Should it also turn when the unfolded phone turns (7.7)?
6. **Pause on fold (Bart):** should folding or unfolding mid-wave pause the game? It already pauses when the fold causes a focus loss.
7. **The look (DM, with the art director):** the theme slice draws free curved roads and round pads at free positions. This contract uses a grid with rounded roads through cell centers. Does the look survive?
8. **Remember difficulty (Bart):** should the level card remember Relaxed for a player who always picks it?
9. **Frame rate cap (DM):** set `application/run/max_fps=60` after the Fold5 measurement?
