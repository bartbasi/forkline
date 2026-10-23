# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Shared fixtures for tests/sim/: the real stat files, test maps and helpers.
## Test maps live here, not in data/levels/.

const STATS_DIR: String = "res://data/stats/"

## The contract's example fork (docs/ARCHITECTURE.md 2.4). Both branches are 13 steps,
## so with no gate the tie break sends walkers west. Sockets at [1, 3] and [5, 5].
const FORK_GRID: Array = [
	"...1...",
	"o..#..o",
	".#####.",
	".G.o.#.",
	".#...#.",
	".#.o.G.",
	".#...#.",
	".#.o.#.",
	".#####.",
	"..oBo..",
]

## A straight road down column 3: entrance [3, 0], base [3, 7], 7 steps.
const LINE_GRID: Array = [
	"...1...",
	"..o#o..",
	"...#...",
	"..o#o..",
	"...#...",
	"...#...",
	"..o#o..",
	"...B...",
]

## Three branches between [3, 2] and [3, 8], each with a socket, and two entrances.
const TRIPLE_GRID: Array = [
	"1.....2",
	"#..o..#",
	"#######",
	"G..G..G",
	"#..#..#",
	"#.o#o.#",
	"#..#..#",
	"#######",
	"...#...",
	"...B...",
]


static func parse(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func stats_files() -> Array:
	return [parse(STATS_DIR + "towers.json"), parse(STATS_DIR + "enemies.json"), parse(STATS_DIR + "rules.json")]


static func catalog() -> Catalog:
	var files: Array = stats_files()
	return Catalog.from_data(files[0], files[1], files[2])


## A catalog from the real files with one creature's fields changed.
static func catalog_with_enemy(id: String, changes: Dictionary) -> Catalog:
	var files: Array = stats_files()
	for item: Dictionary in files[1]["enemies"]:
		if item["id"] == id:
			item.merge(changes, true)
	return Catalog.from_data(files[0], files[1], files[2])


static func group(enemy: String, count: int, at_ms: int = 0, every_ms: int = 1000, entrance: int = 1) -> Dictionary:
	return {"enemy": enemy, "count": count, "entrance": entrance, "at_ms": at_ms, "every_ms": every_ms}


## A valid level dictionary. Pass changes to override top level keys.
static func level_data(grid: Array, waves: Array, changes: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"format": 1, "id": "test_map", "name": "Test Map", "grid": grid.duplicate(),
		"start_gold": 1000, "gates": 0, "strength": 100,
		"towers": ["sling_post", "pumpkin_catapult"],
		"star3": {"kind": "no_lives_lost"},
		"waves": waves.duplicate(true),
	}
	data.merge(changes, true)
	return data


static func level(grid: Array, waves: Array, changes: Dictionary = {}, stats: Catalog = null) -> LevelData:
	var cat: Catalog = stats if stats != null else catalog()
	return LevelData.from_data(level_data(grid, waves, changes), cat)


static func battle(grid: Array, waves: Array, changes: Dictionary = {}, stats: Catalog = null, relaxed: bool = false) -> Battle:
	var cat: Catalog = stats if stats != null else catalog()
	var lvl: LevelData = LevelData.from_data(level_data(grid, waves, changes), cat)
	return Battle.create(lvl, cat, relaxed, [])


## Steps until the phase changes or the tick limit. Returns ticks run.
static func run_wave(b: Battle, limit: int = 20000) -> int:
	var ran: int = 0
	while b.phase == Battle.Phase.WAVE and ran < limit:
		b.step()
		ran += 1
	return ran


## Steps n ticks.
static func steps(b: Battle, n: int) -> void:
	for i: int in n:
		b.step()


static func events_of(events: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["kind"] == kind:
			out.append(event)
	return out


static func snapshot(b: Battle) -> String:
	return JSON.stringify(b.to_data())


## A copy through JSON text, as a save file would give it.
static func restored(b: Battle) -> Battle:
	return Battle.from_data(JSON.parse_string(JSON.stringify(b.to_data())), b.catalog)
