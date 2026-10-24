# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Saved games: one per mode, resumed at the exact moment, the Continue order, and
## invalid saves deleted (docs/ARCHITECTURE.md 3.5, 5.4, 5.5, 5.6, 6; RULES 4.10, 14.7).

const Fx: GDScript = preload("res://tests/save/fixtures/save_fixtures.gd")

var game: GameData = null
var store: SaveStore = null


func before_each() -> void:
	Fx.fresh()
	game = Fx.game()
	store = SaveStore.new(Fx.WORK)


func after_each() -> void:
	store = null
	Fx.clean()


func _find(list: Array[SavedGame], mode: StringName) -> SavedGame:
	for saved: SavedGame in list:
		if saved.mode == mode:
			return saved
	return null


func _modes(list: Array[SavedGame]) -> Array[StringName]:
	var out: Array[StringName] = []
	for saved: SavedGame in list:
		out.append(saved.mode)
	return out


func test_each_mode_resumes_to_an_identical_battle() -> void:
	var battles: Dictionary = {
		SavedGame.LEVEL: Fx.battle_mid_wave(game, &"r1_l1", false, 150),
		SavedGame.RUN: Fx.battle_mid_wave(game, &"r1_l5", true, 260),
		SavedGame.DAILY: Fx.battle_mid_wave(game, &"r1_l6", false, 333),
	}
	for mode: StringName in battles:
		var battle: Battle = battles[mode]
		assert_eq(battle.phase, Battle.Phase.WAVE, String(mode))
		assert_false(battle.enemies.is_empty(), "%s has creatures on the map" % mode)
		assert_true(store.save_game(Fx.saved(mode, battle)), String(mode))
	var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
	assert_eq(loaded.size(), 3)
	for mode: StringName in battles:
		var original: Battle = battles[mode]
		var saved: SavedGame = _find(loaded, mode)
		assert_not_null(saved, String(mode))
		if saved == null:
			continue
		assert_eq(Fx.battle_text(saved.battle), Fx.battle_text(original), "%s resumes at the exact moment" % mode)
		assert_eq(saved.level_id, original.level.id if mode == SavedGame.LEVEL else &"")
		# Played on, the resumed battle stays the same as the one never saved.
		for i: int in 400:
			original.step()
			saved.battle.step()
		assert_eq(Fx.battle_text(saved.battle), Fx.battle_text(original), "%s plays on the same" % mode)


func test_build_phase_resumes_too() -> void:
	var battle: Battle = Battle.create(game.levels[&"r1_l2"], game.catalog, false, [])
	battle.place_tower(battle.level.spots[1], &"pumpkin_catapult")
	battle.place_gate(battle.level.sockets[0])
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, battle)))
	var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
	assert_eq(loaded.size(), 1)
	assert_eq(Fx.battle_text(loaded[0].battle), Fx.battle_text(battle))
	assert_eq(loaded[0].battle.phase, Battle.Phase.BUILD)


func test_continue_picks_the_most_recent() -> void:
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 10))))
	assert_true(store.save_game(Fx.saved(SavedGame.DAILY, Fx.battle_mid_wave(game, &"r1_l2", false, 10))))
	assert_true(store.save_game(Fx.saved(SavedGame.RUN, Fx.battle_mid_wave(game, &"r1_l3", false, 10))))
	var next: SaveStore = SaveStore.new(Fx.WORK)
	var loaded: Array[SavedGame] = next.load_games(game)
	assert_eq(_modes(loaded), [SavedGame.RUN, SavedGame.DAILY, SavedGame.LEVEL] as Array[StringName])
	# Saving the level again makes it the most recent, in this launch and the next.
	var level_game: SavedGame = _find(loaded, SavedGame.LEVEL)
	level_game.battle.step()
	assert_true(next.save_game(level_game))
	assert_eq(_modes(SaveStore.new(Fx.WORK).load_games(game))[0], SavedGame.LEVEL)
	assert_true(level_game.order > _find(loaded, SavedGame.RUN).order)


func test_modes_stay_separate() -> void:
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 10))))
	assert_true(store.save_game(Fx.saved(SavedGame.RUN, Fx.battle_mid_wave(game, &"r1_l2", false, 10))))
	assert_true(store.save_game(Fx.saved(SavedGame.DAILY, Fx.battle_mid_wave(game, &"r1_l3", false, 10))))
	assert_true(Fx.exists("game_level.json"))
	assert_true(Fx.exists("game_run.json"))
	assert_true(Fx.exists("game_daily.json"))
	# A second level replaces only the level's game.
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l4", false, 10))))
	store.delete_game(SavedGame.RUN)
	assert_false(Fx.exists("game_run.json"))
	assert_false(Fx.exists("game_run.json.bak"))
	var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
	assert_eq(_modes(loaded), [SavedGame.LEVEL, SavedGame.DAILY] as Array[StringName])
	assert_eq(_find(loaded, SavedGame.LEVEL).level_id, &"r1_l4")


func test_games_that_cannot_be_saved_are_refused() -> void:
	assert_false(store.save_game(null))
	var empty: SavedGame = SavedGame.new()
	assert_false(store.save_game(empty), "no battle")
	var odd: SavedGame = Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 5))
	odd.mode = &"arena"
	assert_false(store.save_game(odd), "unknown mode")
	var lost: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 0)
	lost.lives = 1
	for i: int in 100000:
		if lost.phase == Battle.Phase.WON or lost.phase == Battle.Phase.LOST:
			break
		if lost.phase == Battle.Phase.BUILD:
			lost.start_next_wave()
		else:
			lost.step()
	assert_true(lost.phase == Battle.Phase.WON or lost.phase == Battle.Phase.LOST)
	assert_false(store.save_game(Fx.saved(SavedGame.LEVEL, lost)), "a finished battle is not saved")
	assert_eq(DirAccess.get_files_at(Fx.WORK).size(), 0)


func test_tmp_wins_for_a_saved_game() -> void:
	var older: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 20)
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, older)))
	var newer: SavedGame = Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 90))
	newer.order = 50
	Fx.write_text("game_level.json.tmp", JsonFile.to_text(newer.to_data()))
	var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
	assert_eq(loaded[0].battle.tick, newer.battle.tick)
	assert_false(Fx.exists("game_level.json.tmp"))


func test_bak_is_used_when_the_saved_game_is_bad() -> void:
	var first: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 20)
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, first)))
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 40))))
	var text: String = Fx.read_text("game_level.json")
	Fx.write_text("game_level.json", text.left(text.length() / 3))
	Fx.write_text("game_level.json.tmp", "{\"format\": 1}")
	var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
	assert_eq(loaded.size(), 1)
	assert_eq(Fx.battle_text(loaded[0].battle), Fx.battle_text(first), "one save behind")
	assert_false(Fx.exists("game_level.json.tmp"), "a bad .tmp is deleted")


func test_no_valid_copy_deletes_all_three() -> void:
	Fx.write_text("game_run.json", "{\"format\": 1, \"mode\": \"run\"")
	Fx.write_text("game_run.json.bak", "[]")
	Fx.write_text("game_run.json.tmp", "")
	assert_eq(store.load_games(game).size(), 0)
	assert_false(Fx.exists("game_run.json"))
	assert_false(Fx.exists("game_run.json.bak"))
	assert_false(Fx.exists("game_run.json.tmp"))


func test_tampered_fields_make_the_game_invalid() -> void:
	var battle: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 120)
	var base: Dictionary = Fx.saved(SavedGame.LEVEL, battle).to_data()
	base["order"] = 3
	var cases: Dictionary = {
		"format 2": {"format": 2},
		"format text": {"format": "1"},
		"mode unknown": {"mode": "arena"},
		"mode of another file": {"mode": "run", "level_id": ""},
		"order past ceiling": {"order": 1e13},
		"order negative": {"order": -1},
		"order infinite": {"order": INF},
		"order fraction": {"order": 2.5},
		"level unknown": {"level_id": "r9_l9"},
		"level path": {"level_id": "../stats/rules"},
		"level other than battle": {"level_id": "r1_l2"},
		"twist without a Twist": {"twist": true},
		"twist as number": {"twist": 1},
		"run not null": {"run": {}},
		"battle missing": {"battle": null},
		"battle as text": {"battle": "res://src/sim/battle.gd"},
		"extra key": {"cheat": true},
	}
	var battle_cases: Dictionary = {
		"gold past ceiling": {"gold": 1e10},
		"gold infinite": {"gold": INF},
		"lives zero": {"lives": 0},
		"tick negative": {"tick": -5},
		"phase won": {"phase": "won"},
		"enemies wrong type": {"enemies": {"a": 1}},
		"level broken": {"level": {"format": 1}},
	}
	for name: String in battle_cases:
		var changed: Dictionary = base["battle"].duplicate(true)
		changed.merge(battle_cases[name], true)
		cases[name] = {"battle": changed}
	for name: String in cases:
		var data: Dictionary = base.duplicate(true)
		data.merge(cases[name], true)
		if name == "extra key":
			data["cheat"] = true
		var text: String = JSON.stringify(data)
		Fx.write_text("game_level.json", text)
		var loaded: Array[SavedGame] = SaveStore.new(Fx.WORK).load_games(game)
		assert_eq(loaded.size(), 0, name)
		assert_false(Fx.exists("game_level.json"), "%s: deleted" % name)
	# The untouched data is valid, so each refusal above came from its one change.
	Fx.write_text("game_level.json", JSON.stringify(base))
	assert_eq(SaveStore.new(Fx.WORK).load_games(game).size(), 1)


func test_daily_is_always_normal() -> void:
	var relaxed: Battle = Fx.battle_mid_wave(game, &"r1_l1", true, 10)
	var data: Dictionary = Fx.saved(SavedGame.DAILY, relaxed).to_data()
	assert_null(SavedGame.from_data(JSON.parse_string(JSON.stringify(data)), game))
	data["mode"] = "run"
	assert_not_null(SavedGame.from_data(JSON.parse_string(JSON.stringify(data)), game))


func test_game_in_the_wrong_file_is_deleted() -> void:
	var data: Dictionary = Fx.saved(SavedGame.RUN, Fx.battle_mid_wave(game, &"r1_l1", false, 10)).to_data()
	Fx.write_text("game_daily.json", JSON.stringify(data))
	assert_eq(store.load_games(game).size(), 0)
	assert_false(Fx.exists("game_daily.json"))


func test_needs_valid_game_data() -> void:
	var data: Dictionary = Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 10)).to_data()
	assert_null(SavedGame.from_data(data, null))
	assert_null(SavedGame.from_data(data, GameData.new()))


## r1_l1 with a Twist added, as a level file would give it.
func _twist_game() -> GameData:
	var data: Dictionary = game.levels[&"r1_l1"].to_data()
	data["twist"] = {"name": "Thin Purse", "text": "Start with half the gold.",
		"effects": [{"type": "start_gold_pct", "pct": 50}, {"type": "speed_pct", "pct": 120}]}
	var twisted: LevelData = LevelData.from_data(JSON.parse_string(JSON.stringify(data)), game.catalog)
	assert_not_null(twisted)
	game.levels[&"r1_l1"] = twisted
	return game


func test_a_twist_game_must_hold_its_levels_twist_rules_13() -> void:
	var twisted: GameData = _twist_game()
	var level: LevelData = twisted.levels[&"r1_l1"]
	var battle: Battle = Battle.create(level, twisted.catalog, false, level.twist_effects)
	battle.place_tower(level.spots[0], level.towers[0])
	battle.start_next_wave()
	for i: int in 40:
		battle.step()
	var saved: SavedGame = Fx.saved(SavedGame.LEVEL, battle)
	saved.twist = true
	var data: Dictionary = JSON.parse_string(JSON.stringify(saved.to_data()))
	assert_not_null(SavedGame.from_data(data, twisted), "the Twist game loads")
	var plain: Dictionary = data.duplicate(true)
	plain["twist"] = false
	assert_null(SavedGame.from_data(plain, twisted), "a Twist battle saved as the plain level")
	var other: Dictionary = data.duplicate(true)
	other["battle"]["twist"] = [{"type": "start_gold_pct", "pct": 50}]
	assert_null(SavedGame.from_data(other, twisted), "Twist effects that are not the level's")
	var plain_battle: Dictionary = Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(twisted, &"r1_l1", false, 40)).to_data()
	var claimed: Dictionary = JSON.parse_string(JSON.stringify(plain_battle))
	claimed["twist"] = true
	assert_null(SavedGame.from_data(claimed, twisted), "a plain battle claiming the Twist")


func test_a_campaign_game_holds_no_cards_and_a_run_no_twist_rules_13_and_14() -> void:
	var battle: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 40)
	assert_eq(battle.add_effects([{"type": "bounty_pct", "pct": 200}] as Array[Dictionary], false), Battle.DONE)
	var as_level: Dictionary = JSON.parse_string(JSON.stringify(Fx.saved(SavedGame.LEVEL, battle).to_data()))
	assert_null(SavedGame.from_data(as_level, game), "a campaign level with a card")
	var as_run: Dictionary = JSON.parse_string(JSON.stringify(Fx.saved(SavedGame.RUN, battle).to_data()))
	assert_not_null(SavedGame.from_data(as_run, game), "a run takes cards")
	var twisted: Dictionary = as_run.duplicate(true)
	twisted["battle"]["twist"] = [{"type": "no_selling"}]
	assert_null(SavedGame.from_data(twisted, game), "a run has no Twist")


## A campaign battle on 1-1 after a card or risk card the campaign never offers.
func _after_card(effects: Array[Dictionary], risk: bool) -> Battle:
	var battle: Battle = Battle.create(game.levels[&"r1_l1"], game.catalog, false, [])
	battle.place_tower(battle.level.spots[0], battle.level.towers[0])
	assert_eq(battle.add_effects(effects, risk), Battle.DONE, str(effects))
	battle.start_next_wave()
	for i: int in 40:
		battle.step()
	assert_eq(battle.phase, Battle.Phase.WAVE)
	return battle


func test_a_campaign_game_holds_nothing_only_cards_give_contract_2_8() -> void:
	# Only risk cards make a wave take a risk card or open every gate, and only cards add
	# gates. Each of these loads as a run and is refused as a campaign level.
	var cases: Array = [
		["a wave that took a risk card", _after_card([{"type": "reward_gold", "amount": 50}] as Array[Dictionary], true), "wave_risk"],
		["gates standing open", _after_card([{"type": "gates_open"}] as Array[Dictionary], true), "gates_open"],
		["gates added by a card", _after_card([{"type": "add_gates", "count": 1}] as Array[Dictionary], false), "gates_added"],
	]
	for item: Array in cases:
		var battle: Battle = item[1]
		var as_run: Dictionary = JSON.parse_string(JSON.stringify(Fx.saved(SavedGame.RUN, battle).to_data()))
		assert_not_null(SavedGame.from_data(as_run, game), "%s loads as a run" % item[0])
		var as_level: Dictionary = JSON.parse_string(JSON.stringify(Fx.saved(SavedGame.LEVEL, battle).to_data()))
		var inner: Dictionary = as_level["battle"]
		assert_true(inner[item[2]] is Array and not (inner[item[2]] as Array).is_empty() or inner[item[2]] is bool and inner[item[2]] or inner[item[2]] is float and inner[item[2]] > 0, "%s shows in %s" % [item[0], item[2]])
		assert_true((inner["effects"] as Array).is_empty() and (inner["risk"] as Array).is_empty(), "%s keeps no card" % item[0])
		assert_null(SavedGame.from_data(as_level, game), "%s is refused as a campaign level" % item[0])
	var plain: Battle = Fx.battle_mid_wave(game, &"r1_l1", false, 40)
	assert_not_null(SavedGame.from_data(JSON.parse_string(JSON.stringify(Fx.saved(SavedGame.LEVEL, plain).to_data())), game), "a plain level loads")
