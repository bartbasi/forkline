# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Load ceilings on a saved battle as a whole (docs/ARCHITECTURE.md 5.6): the crowd of
## creatures, the creatures that summon, and the seal check in a wave. The tampered saves
## of the security review of 2026-10-25 (L1, L2) are refused, and real play at its worst
## moments still loads.

const Fx: GDScript = preload("res://tests/save/fixtures/save_fixtures.gd")
const LIMIT: int = 60000

var game: GameData = null
var store: SaveStore = null


func before_each() -> void:
	Fx.fresh()
	game = Fx.game()
	store = SaveStore.new(Fx.WORK)


func after_each() -> void:
	store = null
	Fx.clean()


## The review's start: r1_l2, one tower, some ticks into wave 1, as a file brings it back.
func _level_save(ticks: int) -> Dictionary:
	var battle: Battle = Fx.battle_mid_wave(game, &"r1_l2", false, ticks)
	assert_eq(battle.phase, Battle.Phase.WAVE)
	return Fx.through_json(Fx.saved(SavedGame.LEVEL, battle).to_data())


func _loads(data: Dictionary) -> bool:
	return SavedGame.from_data(Fx.through_json(data), game) != null


## A release at entrance 1 that starts on the saved tick.
func _release(battle: Dictionary, enemy: String, left: int) -> Dictionary:
	var entrance: Array = DataCheck.cell_data(game.levels[&"r1_l2"].entrances[0])
	return {"enemy": enemy, "wave": battle["running"][0], "left": left, "next": battle["tick"], "gap": 1,
		"from": entrance, "to": entrance.duplicate(), "progress": Sim.UNIT}


## Adds count Grumblesacks, copies of the first creature, with new ids.
func _add_bosses(battle: Dictionary, count: int) -> void:
	var model: Dictionary = battle["enemies"][0]
	for i: int in count:
		var boss: Dictionary = model.duplicate(true)
		boss["id"] = int(battle["next_id"])
		battle["next_id"] = int(battle["next_id"]) + 1
		boss["type"] = "grumblesack"
		boss["max_health"] = 2000
		boss["health"] = 2000
		boss["summon_at"] = int(battle["tick"]) + 1
		(battle["enemies"] as Array).append(boss)


# L1: the crowd as a whole.

func test_review_l1_a_thousand_full_releases_are_refused() -> void:
	var data: Dictionary = _level_save(20)
	var battle: Dictionary = data["battle"]
	var list: Array = []
	for i: int in Battle.MAX_RELEASES:
		list.append(_release(battle, "scamp", 200))
	battle["releases"] = list
	battle["lives"] = Battle.MAX_LIVES
	battle["start_lives"] = Battle.MAX_LIVES
	Fx.write_text("game_level.json", JSON.stringify(data))
	assert_true(store.load_games(game).is_empty(), "the tampered save is refused")
	assert_false(Fx.exists("game_level.json"), "and deleted")


func test_live_creatures_and_creatures_to_come_stop_at_max_enemies() -> void:
	var data: Dictionary = _level_save(60)
	var battle: Dictionary = data["battle"]
	var live: int = (battle["enemies"] as Array).size()
	assert_true(live >= 1, "creatures on the map: %d" % live)
	var room: int = Battle.MAX_ENEMIES - live
	var list: Array = []
	while room > 0:
		list.append(_release(battle, "scamp", mini(room, 200)))
		room -= mini(room, 200)
	battle["releases"] = list
	assert_true(_loads(data), "exactly %d in all loads" % Battle.MAX_ENEMIES)
	list.append(_release(battle, "puff", 1))
	assert_false(_loads(data), "one more is refused")


func test_review_l1_a_swarm_of_summoners_is_refused() -> void:
	var data: Dictionary = _level_save(60)
	_add_bosses(data["battle"], 200)
	assert_false(_loads(data), "200 Grumblesacks")


func test_at_most_max_summoners_creatures_summon() -> void:
	var data: Dictionary = _level_save(60)
	var battle: Dictionary = data["battle"]
	_add_bosses(battle, Battle.MAX_SUMMONERS)
	assert_true(_loads(data), "%d Grumblesacks load" % Battle.MAX_SUMMONERS)
	var more: Dictionary = data.duplicate(true)
	_add_bosses(more["battle"], 1)
	assert_false(_loads(more), "one more is refused")
	var released: Dictionary = data.duplicate(true)
	released["battle"]["releases"] = [_release(released["battle"], "grumblesack", 1)]
	assert_false(_loads(released), "a summoner still to come from a release counts too")
	(released["battle"]["enemies"] as Array).pop_back()
	assert_true(_loads(released), "and with one fewer on the map it loads")


# L2: the seal check in a wave.

## The review's L2 save: r1_l2 right after wave 1 starts, two gates given, the gates in
## the given sockets and none in hand.
func _gated_wave(cells: Array[Vector2i]) -> Dictionary:
	var data: Dictionary = _level_save(0)
	var battle: Dictionary = data["battle"]
	assert_true((battle["enemies"] as Array).is_empty(), "no creature has spawned")
	battle["level"]["gates"] = 2
	var list: Array = []
	for cell: Vector2i in cells:
		list.append({"cell": DataCheck.cell_data(cell), "fixed": false, "broken": false})
	battle["gates"] = list
	battle["gates_in_hand"] = 2 - cells.size()
	return data


func test_review_l2_a_wave_save_that_seals_every_road_is_refused() -> void:
	var level: LevelData = game.levels[&"r1_l2"]
	var both: Array[Vector2i] = level.sockets.duplicate()
	assert_eq(both.size(), 2)
	assert_true(RoadMap.new(level).seals(both), "both gates seal r1_l2")
	assert_false(_loads(_gated_wave(both)), "the sealing wave save is refused")
	Fx.write_text("game_level.json", JSON.stringify(_gated_wave(both)))
	assert_true(store.load_games(game).is_empty(), "through the store too")
	assert_false(Fx.exists("game_level.json"))
	assert_true(_loads(_gated_wave([both[0]])), "one gate loads")
	assert_true(_loads(_gated_wave([both[1]])), "the other gate loads")


func test_in_a_wave_broken_gates_and_gates_open_do_not_seal() -> void:
	var both: Array[Vector2i] = game.levels[&"r1_l2"].sockets.duplicate()
	var broken: Dictionary = _gated_wave(both)
	broken["battle"]["gates"][1]["broken"] = true
	assert_true(_loads(broken), "a broken gate is open")
	# gates_open comes only from a risk card, which a campaign save cannot hold, so this
	# one is checked on the battle alone.
	var open: Dictionary = _gated_wave(both)["battle"]
	open["gates_open"] = true
	assert_not_null(Battle.from_data(Fx.through_json(open), game.catalog), "gates_open opens them all")
	open["gates_open"] = false
	assert_null(Battle.from_data(Fx.through_json(open), game.catalog), "and without it they seal")


# Real play at its worst moments still loads.

## Plays a campaign level with lives that never run out, calling every wave as early as
## it may. defend false builds nothing, so the crowd grows as large as play allows;
## true fills every spot. A save is sent through text and SavedGame.from_data at every
## new peak and every 250 ticks. Returns the peaks.
func _play_worst(level_id: StringName, twist: bool, defend: bool) -> Dictionary:
	var level: LevelData = game.levels[level_id]
	var effects: Array[Dictionary] = level.twist_effects if twist else ([] as Array[Dictionary])
	var battle: Battle = Battle.create(level, game.catalog, false, effects)
	battle.lives = Battle.MAX_LIVES
	var peaks: Dictionary = {"live": 0, "crowd": 0, "summoners": 0, "releases": 0, "loads": 0, "refused": 0}
	while (battle.phase == Battle.Phase.BUILD or battle.phase == Battle.Phase.WAVE) and battle.tick < LIMIT:
		var check: bool = battle.tick % 250 == 0
		if battle.phase == Battle.Phase.BUILD:
			check = true
			if defend:
				battle.gold = 1000000
				for i: int in level.spots.size():
					battle.place_tower(level.spots[i], level.towers[i % level.towers.size()])
		battle.start_next_wave()
		battle.step()
		var crowd: int = battle.enemies.size()
		var summoners: int = 0
		for enemy: EnemyState in battle.enemies:
			if not game.catalog.enemy(enemy.type).summon.is_empty():
				summoners += 1
		for release: Battle.Release in battle._releases:
			crowd += release.left
		var now: Dictionary = {"live": battle.enemies.size(), "crowd": crowd, "summoners": summoners, "releases": battle._releases.size()}
		for key: String in now:
			if now[key] > peaks[key]:
				peaks[key] = now[key]
				check = true
		if check and (battle.phase == Battle.Phase.BUILD or battle.phase == Battle.Phase.WAVE):
			var saved: SavedGame = Fx.saved(SavedGame.LEVEL, battle)
			saved.twist = twist
			if SavedGame.from_data(Fx.through_json(saved.to_data()), game) == null:
				peaks["refused"] += 1
			peaks["loads"] += 1
	assert_true(battle.phase == Battle.Phase.WON, "%s twist %s defend %s ends" % [level_id, twist, defend])
	return peaks


## The creatures one wave spawns, counting Puffs, with the Twist when twist is true.
func _wave_size(level: LevelData, w: int, twist: bool) -> int:
	var effects: Array[Dictionary] = level.twist_effects if twist else ([] as Array[Dictionary])
	var total: int = 0
	for group: WaveGroup in level.waves[w].groups:
		var type: EnemyType = game.catalog.enemy(group.enemy)
		total += Modifiers.group_count(effects, group.count, type.flying, w == level.waves.size() - 1) * (1 + type.split_count)
	return total


## The level with the largest wave of the campaign, and every boss level with its Twist
## (Double Trouble brings two bosses), each with no defense and with a full one.
func test_real_play_at_its_worst_moments_still_loads() -> void:
	var largest: Array = [&"", false, 0]
	for level_id: StringName in game.levels:
		var level: LevelData = game.levels[level_id]
		for twist: bool in [false, true]:
			for w: int in level.waves.size():
				if _wave_size(level, w, twist) > largest[2]:
					largest = [level_id, twist, _wave_size(level, w, twist)]
	var plays: Array = [[largest[0], largest[1]]]
	for level_id: StringName in [&"r1_l6", &"r2_l6", &"r3_l6", &"r4_l6"]:
		plays.append([level_id, true])
	var most: Dictionary = {"live": 0, "crowd": 0, "summoners": 0, "releases": 0}
	var loads: int = 0
	for play: Array in plays:
		for defend: bool in [false, true]:
			var peaks: Dictionary = _play_worst(play[0], play[1], defend)
			var label: String = "%s twist %s defend %s" % [play[0], play[1], defend]
			assert_eq(peaks["refused"], 0, label + ": refused saves")
			if not defend and (play[0] == &"r1_l6" or play[0] == &"r3_l6"):
				assert_eq(peaks["summoners"], 2, label + ": Double Trouble brings two summoners at once")
			loads += peaks["loads"]
			for key: String in most:
				most[key] = maxi(most[key], peaks[key])
	assert_true(most["crowd"] * 4 <= Battle.MAX_ENEMIES, "play stays far below the crowd ceiling: %d" % most["crowd"])
	assert_true(most["summoners"] * 4 <= Battle.MAX_SUMMONERS, "and the summoner ceiling: %d" % most["summoners"])
	print("    save: largest wave %d on %s (twist %s); %d worst moment saves loaded; peaks %s" % [largest[2], largest[0], largest[1], loads, str(most)])


## Play can never bring more summoners than a save may hold: every campaign level with
## and without its Twist, and a run's waves (the largest pack of each band, doubled to
## cover any risk card's count change, plus the cards that add groups).
func test_no_level_pack_or_card_brings_more_summoners_than_a_save_may_hold() -> void:
	for level_id: StringName in game.levels:
		var level: LevelData = game.levels[level_id]
		for effects: Array[Dictionary] in [[] as Array[Dictionary], level.twist_effects]:
			var total: int = 0
			for w: int in level.waves.size():
				for group: WaveGroup in level.waves[w].groups:
					var type: EnemyType = game.catalog.enemy(group.enemy)
					if not type.summon.is_empty():
						total += Modifiers.group_count(effects, group.count, type.flying, w == level.waves.size() - 1)
			assert_true(total <= Battle.MAX_SUMMONERS, "%s: %d summoners" % [level_id, total])
	var run_total: int = 0
	for band: int in range(1, 7):
		var band_most: int = 0
		for pack: Dictionary in game.run.packs_of(band):
			var in_pack: int = 0
			for wave: Dictionary in pack["waves"]:
				for group: Dictionary in wave["groups"]:
					if not game.catalog.enemy(StringName(String(group["enemy"]))).summon.is_empty():
						in_pack += int(group["count"]) * 2
			band_most = maxi(band_most, in_pack)
		run_total += band_most
	for card: Dictionary in game.run.cards:
		for effect: Dictionary in card["effects"]:
			if String(effect["type"]) == "add_group":
				var type: EnemyType = game.catalog.enemy(StringName(String(effect["enemy"])))
				assert_true(type.summon.is_empty(), "card %s adds no summoner" % card["id"])
	assert_true(run_total <= Battle.MAX_SUMMONERS, "a run: at most %d summoners" % run_total)
