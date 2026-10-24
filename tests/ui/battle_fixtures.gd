# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Real Battle objects for the panel tests, made from the real level files
## through GameData. Load it with preload; it has no class name.

static var _game: GameData = null


static func game() -> GameData:
	if _game == null:
		_game = GameData.load_from("res://data")
	return _game


## A battle on a real campaign level.
static func battle(level_id: StringName = &"r1_l1", relaxed: bool = false) -> Battle:
	return Battle.create(game().levels[level_id], game().catalog, relaxed, [] as Array[Dictionary])


## The same level, but offering every tower in the catalog.
static func all_towers_battle(level_id: StringName = &"r1_l1") -> Battle:
	var data: Dictionary = game().levels[level_id].to_data()
	data["towers"] = game().catalog.tower_ids()
	var level: LevelData = LevelData.from_data(data, game().catalog)
	return Battle.create(level, game().catalog, false, [] as Array[Dictionary])


## A battle on a real level whose first wave is changed (to bring a boss early, say).
static func battle_with_first_wave(groups: Array, level_id: StringName = &"r1_l1") -> Battle:
	var data: Dictionary = game().levels[level_id].to_data()
	data["waves"][0] = {"groups": groups}
	var level: LevelData = LevelData.from_data(data, game().catalog)
	return Battle.create(level, game().catalog, false, [] as Array[Dictionary])


## Steps until the phase leaves WAVE, at most `limit` ticks. Returns ticks run.
static func finish_wave(b: Battle, limit: int = 20000) -> int:
	var ran: int = 0
	while b.phase == Battle.Phase.WAVE and ran < limit:
		b.step()
		ran += 1
	return ran


static func steps(b: Battle, count: int) -> void:
	for i: int in count:
		b.step()
