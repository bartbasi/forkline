# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## The real data/runs/run.json and data/cards/cards.json (docs/ARCHITECTURE.md 2.10, 2.11).
## The real segments and packs come from the level designer. Most tests here use the fixture
## segments and packs; the last ones use the real files.

const Fx: GDScript = preload("res://tests/run/fixtures/run_fixtures.gd")
const RUN_PATH: String = "res://data/runs/run.json"
const CARDS_PATH: String = "res://data/cards/cards.json"
const SEGMENT_DIR: String = "res://data/segments/"

## The 22 base cards then the 12 unlockable ones, in the order of 2.11. Each is
## [id, kind, tower, once, counter, at].
const CARDS: Array = [
	["tower_pumpkin_catapult", "tower", "pumpkin_catapult", true, "", 0],
	["tower_lullaby_bell", "tower", "lullaby_bell", true, "", 0],
	["tower_longbow_loft", "tower", "longbow_loft", true, "", 0],
	["tower_firework_tower", "tower", "firework_tower", true, "", 0],
	["tower_bakery", "tower", "bakery", true, "", 0],
	["sharp_pebbles", "perk", "sling_post", true, "", 0],
	["wide_splash", "perk", "pumpkin_catapult", true, "", 0],
	["deep_lullaby", "perk", "lullaby_bell", true, "", 0],
	["steady_aim", "perk", "longbow_loft", true, "", 0],
	["bigger_bangs", "perk", "firework_tower", true, "", 0],
	["warm_ovens", "perk", "bakery", true, "", 0],
	["spare_gate", "gate", "", false, "", 0],
	["gold_purse", "economy", "", false, "", 0],
	["fat_bounties", "economy", "", true, "", 0],
	["feast_days", "economy", "", true, "", 0],
	["fair_trade", "economy", "", true, "", 0],
	["tea_break", "economy", "", false, "", 0],
	["crowded_night", "risk", "", false, "", 0],
	["thick_hides", "risk", "", false, "", 0],
	["hurry_night", "risk", "", false, "", 0],
	["gateless_night", "risk", "", false, "", 0],
	["flock", "risk", "", false, "", 0],
	["twin_pebbles", "perk", "sling_post", true, "best_run_wave", 6],
	["heavy_pumpkins", "perk", "pumpkin_catapult", true, "best_run_wave", 12],
	["frost_chime", "perk", "lullaby_bell", true, "dailies_finished", 1],
	["volley", "perk", "longbow_loft", true, "runs_won", 1],
	["long_fuse", "perk", "firework_tower", true, "runs_won_normal", 1],
	["spice_rack", "perk", "bakery", true, "stars", 24],
	["piggy_bank", "economy", "", true, "stars", 36],
	["bargain", "economy", "", true, "stars", 48],
	["iron_gate", "gate", "", true, "twists_cleared", 1],
	["moonlit_wager", "risk", "", false, "stars", 60],
	["crasher_escort", "risk", "", false, "risky_wins", 1],
	["pip_parade", "risk", "", false, "stars", 72],
]

var catalog: Catalog = null


func before_each() -> void:
	catalog = Fx.catalog()


func _read(path: String, cap: int) -> Variant:
	var got: Dictionary = JsonFile.read(path, cap)
	assert_eq(got["status"], JsonFile.OK_STATUS, path + " reads through the JSON reader")
	return got["data"]


## The real run plan and cards, with the fixture segments and packs.
func _files() -> Dictionary:
	var files: Dictionary = Fx.files_from_json()
	files["runs/run.json"] = _read(RUN_PATH, 16384)
	files["cards/cards.json"] = _read(CARDS_PATH, 262144)
	return files


func test_the_real_run_plan_and_cards_pass_the_check() -> void:
	var found: PackedStringArray = RunData.check(_files(), catalog)
	assert_eq(found, PackedStringArray(), "\n".join(found))
	assert_not_null(RunData.from_data(_files(), catalog))


func test_the_real_run_plan_is_the_one_in_the_contract() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.strength_start, 100)
	assert_eq(data.strength_step, 10)
	assert_eq(data.start_gold, 300)
	assert_eq(data.gates, 1)
	assert_eq(data.towers, [&"sling_post"])
	assert_eq(data.rows, {"top": 4, "middle": 5, "bottom": 4})
	assert_eq([data.spots_min, data.spots_max, data.sockets_min, data.sockets_max], [11, 12, 2, 5])
	assert_eq(data.bands[0], [&"scamp", &"pip"])
	assert_eq(data.bands[1], [&"skitter", &"flitter", &"shellback"])
	assert_eq(data.bands[2], [&"bubbler", &"puffball"])
	assert_eq(data.bands[3], [&"mender", &"dusk_moth"])
	assert_eq(data.bands[4], [&"gatecrasher"])
	assert_eq(data.bands[5].size(), 0)
	assert_eq([data.weights[&"tower"], data.weights[&"perk"], data.weights[&"gate"], data.weights[&"economy"], data.weights[&"risk"]], [30, 25, 10, 20, 15])


func test_wave_17_has_strength_260() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.strength_start + data.strength_step * 16, 260)


func test_the_real_cards_are_the_34_of_the_contract_in_order() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.cards.size(), CARDS.size())
	var ids: Array[StringName] = data.card_ids()
	for i: int in CARDS.size():
		var want: Array = CARDS[i]
		assert_eq(ids[i], StringName(want[0]), "card %d" % i)
		var card: Dictionary = data.card(StringName(want[0]))
		assert_eq(card["kind"], StringName(want[1]), want[0])
		assert_eq(card["tower"], StringName(want[2]), want[0])
		assert_eq(card["once"], want[3], "once of %s" % want[0])
		if want[4] == "":
			assert_eq(card["unlock"], {}, "%s is a base card" % want[0])
		else:
			assert_eq(card["unlock"], {"counter": want[4], "at": want[5]}, "unlock of %s" % want[0])


func test_the_base_pool_is_the_22_base_cards() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	var base: Array[StringName] = data.pool({})
	assert_eq(base.size(), 22)
	for i: int in 22:
		assert_eq(base[i], StringName(CARDS[i][0]))
	assert_eq(data.card_ids().size(), 34, "the daily uses all 34")
	var every: Dictionary = {
		&"best_run_wave": 12, &"runs_won": 1, &"runs_won_normal": 1, &"dailies_finished": 1,
		&"risky_wins": 1, &"stars": 72, &"twists_cleared": 1,
	}
	assert_eq(data.pool(every), data.card_ids())


func test_each_unlock_opens_at_its_number_and_not_before() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	for want: Array in CARDS:
		if want[4] == "":
			continue
		var id: StringName = StringName(want[0])
		assert_false(data.pool({StringName(want[4]): want[5] - 1}).has(id), "%s before %d" % [want[0], want[5]])
		assert_true(data.pool({StringName(want[4]): want[5]}).has(id), "%s at %d" % [want[0], want[5]])
		assert_true(data.pool({StringName(want[4]): want[5] + 100}).has(id), "%s past %d" % [want[0], want[5]])


func test_unlocks_are_sidegrades_with_a_cost() -> void:
	# RULES 14.6: every unlockable perk carries a cost, so it adds variety and no raw power.
	var data: RunData = RunData.from_data(_files(), catalog)
	for want: Array in CARDS:
		if want[4] == "" or want[1] != "perk":
			continue
		var card: Dictionary = data.card(StringName(want[0]))
		assert_eq(card["effects"].size(), 2, "%s gives and takes" % want[0])


func test_card_words_follow_the_writing_rules() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	for id: StringName in data.card_ids():
		var card: Dictionary = data.card(id)
		for field: String in ["name", "text"]:
			var text: String = card[field]
			assert_false(text.contains("--"), "%s %s has a double hyphen" % [id, field])
			assert_false(text.contains(char(8212)), "%s %s has an em dash" % [id, field])
			assert_false(text.begins_with(" ") or text.ends_with(" "), "%s %s has stray spaces" % [id, field])
		assert_true(card["text"].ends_with("."), "%s ends its text with a full stop" % id)


func test_risk_cards_name_a_reward_and_gate_the_next_wave_only() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	var amounts: Dictionary = {
		&"crowded_night": 100, &"thick_hides": 120, &"hurry_night": 60, &"gateless_night": 60, &"flock": 80,
		&"moonlit_wager": 250, &"crasher_escort": 150, &"pip_parade": 120,
	}
	for id: StringName in amounts.keys():
		var card: Dictionary = data.card(id)
		var rewards: Array = []
		for effect: Dictionary in card["effects"]:
			if effect["type"] == "reward_gold":
				rewards.append(effect["amount"])
		assert_eq(rewards, [amounts[id]], "reward of %s" % id)
		assert_true(card["text"].contains(str(amounts[id])), "%s says its reward" % id)


## The six cards TUNING_RUNS 3.3 changes, pinned word for word.
func test_the_run_tuning_cards_are_as_set_in_g3() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.card(&"tea_break")["text"], "Gain 5 lives, but never more than you started with.")
	assert_eq(data.card(&"tea_break")["effects"][0]["amount"], 5)
	var pebbles: Dictionary = data.card(&"sharp_pebbles")
	assert_eq(pebbles["text"], "Sling Posts deal 1 more damage per hit.")
	assert_eq(pebbles["effects"].size(), 1)
	assert_eq([pebbles["effects"][0]["stat"], pebbles["effects"][0]["amount"]], ["damage", 1])
	var hurry: Dictionary = data.card(&"hurry_night")
	assert_eq(hurry["text"], "Next wave: creatures move 50% faster. Reward: 60 gold, more later.")
	assert_eq([hurry["effects"][0]["type"], hurry["effects"][0]["pct"]], ["speed_pct", 150])
	assert_eq(data.card(&"gateless_night")["text"], "Next wave: your gates stand open. Reward: 60 gold, more later.")
	var parade: Dictionary = data.card(&"pip_parade")
	assert_eq(parade["text"], "Next wave: 16 more Pips. Reward: 120 gold, more in later waves.")
	var group: Dictionary = parade["effects"][0]
	assert_eq([group["type"], group["enemy"], group["count"], group["entrance"], group["at_ms"], group["every_ms"], group["after_last"]], ["add_group", "pip", 16, 1, 1000, 300, false])
	var volley: Dictionary = data.card(&"volley")
	assert_eq(volley["text"], "Longbow Lofts hit 1 more target, but deal 15% less damage.")
	assert_eq([volley["effects"][0]["stat"], volley["effects"][0]["amount"]], ["targets", 1])
	assert_eq([volley["effects"][1]["type"], volley["effects"][1]["stat"], volley["effects"][1]["pct"]], ["tower_pct", "damage", 85])


func test_every_real_card_is_accepted_by_a_battle() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	var level: LevelData = MapAssembler.assemble(1, Fx.run_data(), catalog)
	for id: StringName in data.card_ids():
		var card: Dictionary = data.card(id)
		var battle: Battle = Battle.create(level, catalog, false, [])
		var effects: Array[Dictionary] = card["effects"]
		assert_eq(battle.add_effects(effects, card["kind"] == &"risk"), Battle.DONE, String(id))


## Every real file: run plan, cards, segments and packs.
func _real_files() -> Dictionary:
	var files: Dictionary = {
		"runs/run.json": _read(RUN_PATH, 16384), "cards/cards.json": _read(CARDS_PATH, 262144),
		"segments/index.json": _read(SEGMENT_DIR + "index.json", 16384),
		"segments/packs.json": _read(SEGMENT_DIR + "packs.json", 262144),
	}
	var index: Variant = files["segments/index.json"]
	if typeof(index) == TYPE_DICTIONARY and typeof((index as Dictionary).get("segments", null)) == TYPE_ARRAY:
		for id: Variant in (index as Dictionary)["segments"]:
			if DataCheck.is_id(id):
				files["segments/%s.json" % id] = _read(SEGMENT_DIR + "%s.json" % id, 16384)
	return files


func test_the_real_segments_and_packs_pass() -> void:
	var files: Dictionary = _real_files()
	var found: PackedStringArray = RunData.check(files, catalog)
	assert_eq(found, PackedStringArray(), "
".join(found))
	var data: RunData = RunData.from_data(files, catalog)
	assert_not_null(data)
	if data == null:
		return
	# Every stack of the real segments is a valid map (2.9), and a run from a seed builds.
	var packs: Array[StringName] = []
	for band: int in range(1, 7):
		packs.append(data.packs_of(band)[0]["id"])
	var stacks: int = 0
	for top: Dictionary in data.segments_of(&"top"):
		for middle: Dictionary in data.segments_under(top["id"]):
			for bottom: Dictionary in data.segments_under(middle["id"]):
				var level: LevelData = MapAssembler.build(data, catalog, top["id"], middle["id"], bottom["id"], packs)
				assert_not_null(level, "%s / %s / %s" % [top["id"], middle["id"], bottom["id"]])
				stacks += 1
	assert_true(stacks > 0, "the real segments make at least one stack")
	for run_seed: int in 50:
		assert_not_null(MapAssembler.assemble(run_seed, data, catalog), "seed %d" % run_seed)


## Real runs start from the real pools, and the real pools can always fill a draft.
func test_real_runs_start_with_the_real_pools() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	for id: StringName in [&"gold_purse", &"tea_break"]:
		assert_false(bool(data.card(id)["once"]), "%s can be taken again" % id)
		assert_eq(data.card(id)["kind"], &"economy")
		assert_true(data.pool({}).has(id), "%s is in the base pool" % id)
	for run_seed: int in [0, 1, 2, 12345, 4294967295]:
		var s: RunSession = RunSession.start(run_seed, "", false, data.pool({}), data, catalog)
		assert_not_null(s, "seed %d, base pool" % run_seed)
		assert_not_null(RunSession.start(run_seed, "", true, data.card_ids(), data, catalog), "seed %d, every card, Relaxed" % run_seed)
	var day: String = "2026-10-24"
	var daily: RunSession = RunSession.start(RunSeeds.daily_seed(day), day, false, data.card_ids(), data, catalog)
	assert_not_null(daily)
	if daily != null:
		assert_eq(daily.card(&"gold_purse")["kind"], &"economy")
		assert_eq(daily.drafts_owed(), 0)


## TUNING_RUNS 1.2: each band 6 pack's boss wave sets its own strength, and no other wave does.
func test_the_real_boss_waves_set_the_strengths_of_g3() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var want: Dictionary = {
		&"b6_grumble_hill": 290, &"b6_grumble_march": 270, &"b6_iron_road": 150, &"b6_iron_gate": 150,
		&"b6_moon_rise": 150, &"b6_moon_tide": 140, &"b6_tusk_charge": 200, &"b6_tusk_night": 180,
	}
	var seen: int = 0
	for pack: Dictionary in data.packs:
		for k: int in 3:
			var wave: Dictionary = pack["waves"][k]
			if pack["band"] == 6 and k == 2:
				assert_eq(wave["strength"], want.get(pack["id"], -1), "boss wave of %s" % pack["id"])
				seen += 1
			else:
				assert_false(wave.has("strength"), "%s wave %d has no strength" % [pack["id"], k + 1])
	assert_eq(seen, want.size())


## A real run's wave 18 takes the strength of the band 6 pack its seed picked.
func test_a_real_runs_wave_18_takes_its_packs_strength() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	for run_seed: int in [1, 2, 3, 12345, 20261023]:
		var level: LevelData = MapAssembler.assemble(run_seed, data, catalog)
		var picks: Dictionary = MapAssembler.plan(run_seed, data)
		var pack: Dictionary = {}
		for item: Dictionary in data.packs:
			if item["id"] == picks["packs"][5]:
				pack = item
		assert_eq(level.waves[17].strength, pack["waves"][2]["strength"], "seed %d" % run_seed)
		assert_eq(level.waves[16].strength, 260, "wave 17 keeps the step")
