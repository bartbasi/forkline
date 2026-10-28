# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## The creatures and bosses of regions 5 and 6 as test data, with the numbers of RULES
## 6.1 and 6.3, added to the real stat files and the four expansion towers. data/stats/
## gets them in E5.1 and E6.1 (game designer); until then the rules are proven on this
## test-only catalog (docs/ARCHITECTURE.md 14.4).

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")
const Tx: GDScript = preload("res://tests/sim/fixtures/tower_fixtures.gd")

const NEW: Array = ["mossbud", "mistwisp", "gleamer", "sleepyhead", "burrowbelly", "old_hayrick"]


## RULES 6.1 and 6.3, in the file's units.
static func enemies() -> Array:
	return [
		{"id": "mossbud", "name": "Mossbud", "info": "Regrows.", "health": 80, "armor": 0, "speed": 80, "lives": 1, "bounty": 10,
			"regrow": 4, "regrow_ms": 1000},
		{"id": "mistwisp", "name": "Mistwisp", "info": "Hides others.", "health": 50, "armor": 0, "speed": 100, "lives": 1, "bounty": 10,
			"mist": true},
		{"id": "gleamer", "name": "Gleamer", "info": "Dazzles.", "health": 160, "armor": 0, "speed": 80, "lives": 2, "bounty": 18,
			"dazzle": true},
		{"id": "sleepyhead", "name": "Sleepyhead", "info": "Naps once.", "health": 90, "armor": 0, "speed": 90, "lives": 1, "bounty": 12,
			"nap_ms": 2000},
		{"id": "burrowbelly", "name": "Burrowbelly", "info": "Digs.", "health": 3200, "armor": 2, "speed": 40, "lives": 20, "bounty": 300,
			"boss": true, "dig_first_ms": 6000, "dig_every_ms": 8000, "dig_ms": 2000,
			"summon": {"enemy": "mistwisp", "count": 2, "every_ms": 8000, "gap_ms": 300}},
		{"id": "old_hayrick", "name": "Old Hayrick", "info": "Dazzles and naps.", "health": 2600, "armor": 0, "speed": 40, "lives": 20,
			"bounty": 300, "boss": true, "dazzle": true, "nap_ms": 3000},
	]


## The real stat files with the four towers and these creatures added.
static func stats_files() -> Array:
	var files: Array = Tx.stats_files()
	(files[1]["enemies"] as Array).append_array(enemies())
	return files


static func catalog() -> Catalog:
	var files: Array = stats_files()
	return Catalog.from_data(files[0], files[1], files[2])


## A catalog with one creature's fields changed (a null value removes the key).
static func catalog_with(id: String, changes: Dictionary) -> Catalog:
	var files: Array = stats_files()
	for item: Dictionary in files[1]["enemies"]:
		if item["id"] == id:
			for key: String in changes:
				if changes[key] == null:
					item.erase(key)
				else:
					item[key] = changes[key]
	return Catalog.from_data(files[0], files[1], files[2])


## A battle offering every tower, old and new.
static func battle(grid: Array, waves: Array, changes: Dictionary = {}, stats: Catalog = null) -> Battle:
	return Tx.battle(grid, waves, changes, stats if stats != null else catalog())
