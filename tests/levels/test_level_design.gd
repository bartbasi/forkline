# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## The campaign's design rules on the real level files (RULES 3.1, 3.4, 10.3, 12.2 to
## 12.5; docs/ARCHITECTURE.md 2.4, 2.7, 10). Tests compare ids and numbers, never names.

const Files: GDScript = preload("res://tests/levels/fixtures/level_files.gd")

## RULES 12.3 and 12.4, one row per level in play order:
## gates, sockets, waves, strength, Normal starting gold, star 3 kind and value,
## and the kind of cell the hint highlights.
const PLAN: Dictionary = {
	"r1_l1": {"gates": 0, "sockets": 0, "waves": 8, "strength": 100, "gold": 200, "star3": ["no_lives_lost", 0], "highlight": "spot"},
	"r1_l2": {"gates": 1, "sockets": 2, "waves": 8, "strength": 100, "gold": 250, "star3": ["towers_at_most", 4], "highlight": "socket"},
	"r1_l3": {"gates": 1, "sockets": 2, "waves": 9, "strength": 100, "gold": 250, "star3": ["towers_at_most", 3], "highlight": "spot"},
	"r1_l4": {"gates": 1, "sockets": 3, "waves": 9, "strength": 100, "gold": 300, "star3": ["gates_at_most", 0], "highlight": "spot"},
	"r1_l5": {"gates": 1, "sockets": 3, "waves": 10, "strength": 100, "gold": 300, "star3": ["no_lives_lost", 0], "highlight": "spot"},
	"r1_l6": {"gates": 1, "sockets": 3, "waves": 10, "strength": 110, "gold": 350, "star3": ["early_calls_at_least", 4], "highlight": "spot"},
}

## RULES 12.2: the towers each level brings.
const NEW_TOWERS: Dictionary = {
	"r1_l1": ["sling_post", "pumpkin_catapult"],
}

## RULES 12.2 and 12.3: the creature each level brings and its first wave, 1 based.
const NEW_CREATURES: Dictionary = {
	"r1_l1": ["scamp", 1],
	"r1_l4": ["pip", 3],
	"r1_l5": ["flitter", 3],
	"r1_l6": ["grumblesack", 10],
}

## RULES 3.1 and 3.4: map rows and build spots per region, and region 1's one entrance (12.3).
const REGION_ROWS: Dictionary = {"lantern_hill": [8, 11], "millbrook": [10, 13], "willow_fen": [10, 13], "moonspire_keep": [10, 13]}
const REGION_SPOTS: Dictionary = {"lantern_hill": [5, 7], "millbrook": [7, 9], "willow_fen": [8, 10], "moonspire_keep": [9, 11]}
const REGION_ENTRANCES: Dictionary = {"lantern_hill": [1, 1]}

## RULES 12.5: a new creature's first wave holds 3 to 5 of it. A boss comes alone.
const FIRST_WAVE_COUNT: Array[int] = [3, 5]
## docs/ARCHITECTURE.md 2.4 spawn bound, and RULES 12.5's aim for a readable screen.
const SPAWN_BOUND: int = 120
const SPAWN_AIM: int = 80

var catalog: Catalog = null
var order: PackedStringArray = PackedStringArray()
var levels: Dictionary = {}


func before_each() -> void:
	catalog = Files.catalog()
	order = Files.campaign_order()
	for id: String in order:
		var level: LevelData = Files.level(id, catalog)
		if level == null:
			fail("%s does not load" % id)
			continue
		levels[id] = level


func _level(id: String) -> LevelData:
	return levels.get(id, null) as LevelData


## The creature kinds in one wave, in group order, without repeats.
func _kinds(wave: WaveData) -> Array[StringName]:
	var out: Array[StringName] = []
	for group: WaveGroup in wave.groups:
		if not out.has(group.enemy):
			out.append(group.enemy)
	return out


func test_every_campaign_level_has_a_plan_row() -> void:
	var planned: Array = PLAN.keys()
	assert_eq(PackedStringArray(planned), order, "PLAN rows match the campaign order")


func test_numbers_follow_rules_12_3() -> void:
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null or not PLAN.has(id):
			continue
		var plan: Dictionary = PLAN[id]
		assert_eq(level.gates, plan["gates"], "%s gates" % id)
		assert_eq(level.sockets.size(), plan["sockets"], "%s sockets" % id)
		assert_eq(level.waves.size(), plan["waves"], "%s waves" % id)
		assert_eq(level.strength, plan["strength"], "%s strength" % id)
		assert_eq(level.start_gold, plan["gold"], "%s starting gold" % id)


func test_map_size_spots_and_entrances_by_region() -> void:
	var regions: Dictionary = Files.region_of()
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		var region: String = regions.get(id, "")
		assert_true(REGION_ROWS.has(region), "%s: region %s is known" % [id, region])
		if not REGION_ROWS.has(region):
			continue
		var rows: Array = REGION_ROWS[region]
		var spots: Array = REGION_SPOTS[region]
		assert_eq(level.grid.size(), level.rows, "%s rows" % id)
		for line: String in level.grid:
			assert_eq(line.length(), Sim.MAP_COLUMNS, "%s: every row is 7 columns" % id)
		assert_true(level.rows >= int(rows[0]) and level.rows <= int(rows[1]), "%s: %d rows, region allows %s" % [id, level.rows, rows])
		assert_true(level.spots.size() >= int(spots[0]) and level.spots.size() <= int(spots[1]), "%s: %d build spots, region allows %s" % [id, level.spots.size(), spots])
		if REGION_ENTRANCES.has(region):
			var entrances: Array = REGION_ENTRANCES[region]
			assert_true(level.entrances.size() >= int(entrances[0]) and level.entrances.size() <= int(entrances[1]), "%s: %d entrances" % [id, level.entrances.size()])


func test_towers_are_every_tower_brought_by_then() -> void:
	var brought: Array[StringName] = []
	for id: String in order:
		for tower: String in NEW_TOWERS.get(id, []):
			assert_not_null(catalog.tower(StringName(tower)), "%s brings a known tower %s" % [id, tower])
			brought.append(StringName(tower))
		var level: LevelData = _level(id)
		if level == null:
			continue
		var offered: Array[StringName] = level.towers.duplicate()
		offered.sort()
		var expected: Array[StringName] = brought.duplicate()
		expected.sort()
		assert_eq(offered, expected, "%s offers exactly the towers brought by then (RULES 12.2)" % id)


func test_only_creatures_brought_by_then() -> void:
	var brought: Array[StringName] = []
	for id: String in order:
		if NEW_CREATURES.has(id):
			brought.append(StringName(NEW_CREATURES[id][0]))
		var level: LevelData = _level(id)
		if level == null:
			continue
		for i: int in level.waves.size():
			for group: WaveGroup in level.waves[i].groups:
				assert_true(brought.has(group.enemy), "%s wave %d: %s is brought by then" % [id, i + 1, group.enemy])


func test_each_new_creature_comes_alone_first_in_its_planned_wave() -> void:
	var seen: Array[StringName] = []
	var met: Dictionary = {}
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		for i: int in level.waves.size():
			var wave: WaveData = level.waves[i]
			var kinds: Array[StringName] = _kinds(wave)
			var fresh: Array[StringName] = []
			for kind: StringName in kinds:
				if not seen.has(kind):
					fresh.append(kind)
			assert_true(fresh.size() <= 1, "%s wave %d: never two new things in one wave, got %s" % [id, i + 1, fresh])
			if fresh.is_empty():
				continue
			var kind: StringName = fresh[0]
			met[String(kind)] = [id, i + 1]
			assert_eq(kinds.size(), 1, "%s wave %d: %s's first wave holds only it, got %s" % [id, i + 1, kind, kinds])
			var count: int = 0
			for group: WaveGroup in wave.groups:
				count += group.count
			if catalog.enemy(kind) != null and catalog.enemy(kind).boss:
				assert_eq(count, 1, "%s wave %d: a boss comes alone" % [id, i + 1])
			else:
				assert_true(count >= FIRST_WAVE_COUNT[0] and count <= FIRST_WAVE_COUNT[1], "%s wave %d: %d of the new %s, RULES 12.5 asks 3 to 5" % [id, i + 1, count, kind])
			for k: StringName in kinds:
				seen.append(k)
	for id: String in NEW_CREATURES:
		var planned: Array = NEW_CREATURES[id]
		assert_eq(met.get(str(planned[0]), []), [id, int(planned[1])], "%s first appears in %s wave %d" % [planned[0], id, planned[1]])


func test_bosses_only_in_the_final_wave_of_a_regions_last_level() -> void:
	var data: Variant = Files.campaign()
	var last_levels: Array[String] = []
	if data is Dictionary and data.get("regions") is Array:
		for region: Variant in data["regions"]:
			var region_levels: Array = region.get("levels", [])
			if not region_levels.is_empty():
				last_levels.append(str(region_levels[region_levels.size() - 1]))
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		var final_has_boss: bool = false
		for i: int in level.waves.size():
			for group: WaveGroup in level.waves[i].groups:
				var enemy: EnemyType = catalog.enemy(group.enemy)
				if enemy == null or not enemy.boss:
					continue
				assert_eq(i, level.waves.size() - 1, "%s: boss %s only in the final wave" % [id, group.enemy])
				assert_true(last_levels.has(id), "%s: a boss only in a region's last level" % id)
				if i == level.waves.size() - 1:
					final_has_boss = true
		if last_levels.has(id):
			assert_true(final_has_boss, "%s: a region's last level is its boss level" % id)


func test_no_group_of_puffs() -> void:
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		for i: int in level.waves.size():
			for group: WaveGroup in level.waves[i].groups:
				assert_ne(group.enemy, &"puff", "%s wave %d: Puffs come only from Puffballs" % [id, i + 1])


func test_spawn_bound_holds() -> void:
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		for i: int in level.waves.size():
			var total: int = 0
			for group: WaveGroup in level.waves[i].groups:
				var enemy: EnemyType = catalog.enemy(group.enemy)
				var split: int = 0 if enemy == null else enemy.split_count
				total += group.count * (1 + split)
			assert_true(total <= SPAWN_BOUND, "%s wave %d spawns %d, the bound is %d" % [id, i + 1, total, SPAWN_BOUND])
			assert_true(total <= SPAWN_AIM, "%s wave %d spawns %d, RULES 12.5 aims for %d or fewer" % [id, i + 1, total, SPAWN_AIM])


func test_star3_follows_rules_12_4() -> void:
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null or not PLAN.has(id):
			continue
		var planned: Array = PLAN[id]["star3"]
		assert_eq(level.star3.get("kind"), StringName(planned[0]), "%s star 3 kind" % id)
		assert_eq(level.star3.get("value", 0), int(planned[1]), "%s star 3 value" % id)


func test_star3_leaves_two_kinds_of_attacking_tower_usable() -> void:
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null:
			continue
		var kind: StringName = level.star3.get("kind", &"")
		var value: int = level.star3.get("value", 0)
		var usable: Array[StringName] = []
		for tower: StringName in level.towers:
			var type: TowerType = catalog.tower(tower)
			if type == null or type.kind != &"attack":
				continue
			if kind == &"tower_ban" and level.star3.get("tower", &"") == tower:
				continue
			usable.append(tower)
		assert_true(usable.size() >= 2, "%s: star 3 leaves %s as attacking towers" % [id, usable])
		if kind == &"kinds_at_most" or kind == &"towers_at_most":
			assert_true(value >= 2, "%s: star 3 allows two attacking towers" % id)
		if kind == &"tier_at_most":
			assert_true(value >= 1, "%s: star 3 allows building" % id)


func test_hint_highlights_the_planned_kind_of_cell() -> void:
	var kinds: Dictionary = {"spot": LevelData.Kind.SPOT, "socket": LevelData.Kind.SOCKET}
	for id: String in order:
		var level: LevelData = _level(id)
		if level == null or not PLAN.has(id):
			continue
		assert_false(level.hint_text.is_empty(), "%s has a hint (RULES 9.6)" % id)
		assert_eq(level.hint_button, &"", "%s highlights a cell, not a button" % id)
		assert_true(level.hint_cell.x >= 0 and level.hint_cell.y >= 0, "%s highlights a cell" % id)
		var planned: String = PLAN[id]["highlight"]
		assert_eq(level.kind_at(level.hint_cell), kinds[planned], "%s: the hint cell %s is a %s" % [id, level.hint_cell, planned])
