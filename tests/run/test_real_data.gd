# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## The real data/runs/run.json and data/cards/cards.json (docs/ARCHITECTURE.md 2.10, 2.11, 14.8),
## against the real stats. The real segments and packs come from the level designer. Most tests
## here pair the real plan and cards with fixture segments and packs: the regions 1 to 4 fixtures
## plus the tier 1 stand-ins of tier_fixtures.gd. The last ones use the real files.

const Fx: GDScript = preload("res://tests/run/fixtures/run_fixtures.gd")
const Tx: GDScript = preload("res://tests/run/fixtures/tier_fixtures.gd")
const Golden: GDScript = preload("res://tests/run/fixtures/run_golden.gd")
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

## The tier 1 cards of E5.1 (the tower card and the base perk of Bramble Cottage).
const TIER_1_CARDS: Array = ["tower_bramble_cottage", "thorn_tips"]
## The tier 2 cards of E6.1b (the tower card and the base perk of the Scarecrow).
const TIER_2_CARDS: Array = ["tower_scarecrow", "big_hat"]
## The tier 2 creatures: what only a tier 2 player meets (Old Hayrick is the tier 2 boss).
const TIER_2_CREATURES: Array = [&"gleamer", &"sleepyhead"]

var catalog: Catalog = null


func before_each() -> void:
	catalog = Golden.catalog()


func _read(path: String, cap: int) -> Variant:
	var got: Dictionary = JsonFile.read(path, cap)
	assert_eq(got["status"], JsonFile.OK_STATUS, path + " reads through the JSON reader")
	return got["data"]


## The real run plan and cards, with fixture segments and packs: the regions 1 to 4 fixtures
## and the stand-ins of tiers 1 and 2 (tunnel and bridge segments, a Mossbud pack, a Gleamer
## pack, a Burrowbelly pack, an Old Hayrick pack). The real run.json lists both tiers.
func _files() -> Dictionary:
	var files: Dictionary = Tx.files()
	files["runs/run.json"] = _read(RUN_PATH, 16384)
	files["cards/cards.json"] = _read(CARDS_PATH, 262144)
	return files


## _files() with the fixture build spot range, because the fixture segments have fewer than the
## 11 or 12 build spots the real run.json asks of a map. For tests that assemble maps.
func _playable_files() -> Dictionary:
	var files: Dictionary = _files()
	files["runs/run.json"]["spots"] = [8, 12]
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
	assert_eq(data.bands[1], [&"skitter", &"flitter", &"shellback", &"mossbud", &"sleepyhead"])
	assert_eq(data.bands[2], [&"bubbler", &"puffball", &"gleamer"])
	assert_eq(data.bands[3], [&"mender", &"dusk_moth", &"mistwisp"])
	assert_eq(data.bands[4], [&"gatecrasher"])
	assert_eq(data.bands[5].size(), 0)
	assert_eq([data.weights[&"tower"], data.weights[&"perk"], data.weights[&"gate"], data.weights[&"economy"], data.weights[&"risk"]], [30, 25, 10, 20, 15])


func test_wave_17_has_strength_260() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.strength_start + data.strength_step * 16, 260)


func test_the_real_cards_are_the_34_of_the_contract_in_order() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.cards.size(), CARDS.size() + TIER_1_CARDS.size() + TIER_2_CARDS.size(), "the 34 of tier 0, 2 of tier 1 and 2 of tier 2")
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


func test_tier_1_adds_the_bramble_cottage_card_and_perk() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.card_ids(1).size(), 36, "a tier 1 player does not see the Scarecrow cards")
	assert_eq(data.card_ids(0).size(), 34, "tier 0 keeps its 34")
	assert_eq(data.pool({}, 1).size(), 24)
	assert_eq(data.pool({}, 0).size(), 22, "tier 0 keeps its 22")
	for id: StringName in TIER_1_CARDS:
		assert_eq(data.card(id)["tier"], 1, "%s is tier 1" % id)
		assert_false(data.card_ids(0).has(id), "%s is not in the tier 0 daily" % id)
		assert_false(data.pool({}, 0).has(id), "%s is not in the tier 0 pool" % id)
		assert_true(data.pool({}, 1).has(id), "%s is in the tier 1 base pool" % id)
	var tower_card: Dictionary = data.card(&"tower_bramble_cottage")
	assert_eq(tower_card["kind"], &"tower")
	assert_eq(tower_card["tower"], &"bramble_cottage")
	assert_eq(tower_card["name"], "Bramble Cottage")
	assert_eq(tower_card["text"], "You can build Bramble Cottages for the rest of the run.")
	assert_true(tower_card["once"])
	assert_eq(tower_card["unlock"], {})
	assert_eq(tower_card["effects"].size(), 1)
	assert_eq(tower_card["effects"][0]["type"], "add_tower")
	var perk: Dictionary = data.card(&"thorn_tips")
	assert_eq(perk["kind"], &"perk")
	assert_eq(perk["tower"], &"bramble_cottage")
	assert_eq(perk["name"], "Thorn Tips")
	assert_eq(perk["text"], "Bramble Cottages deal 2 more damage per hit.")
	assert_true(perk["once"])
	assert_eq(perk["unlock"], {}, "a base perk")
	assert_eq(perk["effects"].size(), 1)
	assert_eq([perk["effects"][0]["type"], perk["effects"][0]["stat"], perk["effects"][0]["amount"]], ["tower_add", "damage", 2])
	var ids: Array[StringName] = data.card_ids(1)
	assert_eq(ids.find(&"tower_bramble_cottage"), 5, "after the five tower cards")
	assert_eq(ids.find(&"thorn_tips"), 12, "after the six base perks")


func test_tier_2_adds_the_scarecrow_card_and_perk() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.card_ids(2).size(), 38)
	assert_eq(data.card_ids(1).size(), 36, "tier 1 keeps its 36")
	assert_eq(data.card_ids(0).size(), 34, "tier 0 keeps its 34")
	assert_eq(data.pool({}, 2).size(), 26)
	assert_eq(data.pool({}, 1).size(), 24, "tier 1 keeps its 24")
	assert_eq(data.pool({}, 0).size(), 22, "tier 0 keeps its 22")
	var every: Dictionary = {"stars": 1000, "best_run_wave": 1000}
	for id: StringName in TIER_2_CARDS:
		assert_eq(data.card(id)["tier"], 2, "%s is tier 2" % id)
		assert_false(data.card_ids(0).has(id), "%s is not in the tier 0 daily" % id)
		assert_false(data.card_ids(1).has(id), "%s is not in the tier 1 daily" % id)
		assert_false(data.pool(every, 0).has(id), "%s is not in a tier 0 pool" % id)
		assert_false(data.pool(every, 1).has(id), "%s is not in a tier 1 pool" % id)
		assert_true(data.pool({}, 2).has(id), "%s is in the tier 2 base pool" % id)
		assert_true(data.card_ids(2).has(id), "%s is in the tier 2 daily" % id)
	var tower_card: Dictionary = data.card(&"tower_scarecrow")
	assert_eq(tower_card["kind"], &"tower")
	assert_eq(tower_card["tower"], &"scarecrow")
	assert_eq(tower_card["name"], "Scarecrow")
	assert_eq(tower_card["text"], "You can build Scarecrows for the rest of the run.")
	assert_true(tower_card["once"])
	assert_eq(tower_card["unlock"], {})
	assert_eq(tower_card["effects"].size(), 1)
	assert_eq(tower_card["effects"][0]["type"], "add_tower")
	assert_eq(tower_card["effects"][0]["tower"], "scarecrow")
	var perk: Dictionary = data.card(&"big_hat")
	assert_eq(perk["kind"], &"perk")
	assert_eq(perk["tower"], &"scarecrow")
	assert_eq(perk["name"], "Big Hat")
	assert_eq(perk["text"], "Scarecrows reach 0.5 tiles further.")
	assert_true(perk["once"])
	assert_eq(perk["unlock"], {}, "a base perk")
	assert_eq(perk["effects"].size(), 1)
	assert_eq([perk["effects"][0]["type"], perk["effects"][0]["stat"], perk["effects"][0]["amount"]], ["tower_add", "reach", 50])
	var ids: Array[StringName] = data.card_ids(2)
	assert_eq(ids.find(&"tower_scarecrow"), ids.find(&"tower_bramble_cottage") + 1, "after the Bramble Cottage card")
	assert_eq(ids.find(&"big_hat"), ids.find(&"thorn_tips") + 1, "after Thorn Tips")


func test_the_big_hat_adds_half_a_tile_of_reach_to_the_scarecrow() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	var scarecrow: TowerType = catalog.tower(&"scarecrow")
	var bramble: TowerType = catalog.tower(&"bramble_cottage")
	assert_eq(scarecrow.kind, &"fright")
	var effects: Array[Dictionary] = []
	for effect: Dictionary in data.card(&"big_hat")["effects"]:
		effects.append(effect)
	var base: TowerStats = scarecrow.stats(1, -1)
	var hatted: TowerStats = Modifiers.tower_stats(base, &"scarecrow", Modifiers.normalize_all(effects), true)
	assert_eq(hatted.reach, base.reach + 50)
	assert_eq(hatted.fright_pct, base.fright_pct, "the fright itself is unchanged")
	var plain: TowerStats = bramble.stats(1, -1)
	var other: TowerStats = Modifiers.tower_stats(plain, &"bramble_cottage", Modifiers.normalize_all(effects), true)
	assert_eq(other.reach, plain.reach, "it names the Scarecrow only")


func test_the_real_tier_2_in_run_json() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.tiers.size(), 2)
	assert_eq(data.tiers[1]["level"], &"r6_l6")
	assert_eq(data.tiers[1]["towers"], [&"scarecrow"])
	assert_eq(data.tiers[1]["creatures"], TIER_2_CREATURES)
	assert_eq(data.tiers[1]["bosses"], [&"old_hayrick"])
	assert_eq(data.tiers[1]["grid"], "X")
	assert_eq(data.bands[1].find(&"sleepyhead"), data.bands[1].find(&"mossbud") + 1, "Sleepyhead sits after Mossbud in band 2 (RULES 14.3)")
	assert_true(data.bands[2].has(&"gleamer"), "band 3 lists Gleamer")
	for b: int in [0, 3, 4, 5]:
		assert_false(data.bands[b].has(&"gleamer") or data.bands[b].has(&"sleepyhead"), "band %d adds no tier 2 creature" % (b + 1))
	assert_eq(data.boss_ids(2).size(), 6)
	assert_true(data.boss_ids(2).has(&"old_hayrick"))
	assert_false(data.boss_ids(1).has(&"old_hayrick"))
	assert_false(data.boss_ids(0).has(&"old_hayrick"))


func test_the_real_tier_1_in_run_json() -> void:
	var data: RunData = RunData.from_data(_files(), catalog)
	assert_eq(data.tiers.size(), 2)
	assert_eq(data.tiers[0]["level"], &"r5_l6")
	assert_eq(data.tiers[0]["towers"], [&"bramble_cottage"])
	assert_eq(data.tiers[0]["creatures"], [&"mossbud", &"mistwisp"])
	assert_eq(data.tiers[0]["bosses"], [&"burrowbelly"])
	assert_eq(data.tiers[0]["grid"], "T")
	assert_true(data.bands[1].has(&"mossbud"), "band 2 gains Mossbud (RULES 14.3)")
	assert_true(data.bands[3].has(&"mistwisp"), "band 4 gains Mistwisp")
	for b: int in [0, 2, 4, 5]:
		assert_false(data.bands[b].has(&"mossbud") or data.bands[b].has(&"mistwisp"), "band %d adds no tier 1 creature" % (b + 1))
	assert_eq(data.boss_ids(0).size(), 4)
	assert_eq(data.boss_ids(1).size(), 5)
	assert_true(data.boss_ids(1).has(&"burrowbelly"))


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
	var data: RunData = RunData.from_data(_playable_files(), catalog)
	var level: LevelData = MapAssembler.assemble(1, data, catalog)
	assert_not_null(level)
	for id: StringName in data.card_ids(2):
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
			if pack["band"] == 6 and k == 2 and pack["tier"] > 0:
				# The level designer tunes the bosses of regions 5 to 8 (RULES 14.3).
				assert_true(wave.has("strength"), "boss wave of %s sets a strength" % pack["id"])
			elif pack["band"] == 6 and k == 2:
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


## A tier 1 run with the real plan and cards (and tier 1 stand-in segments and packs) starts from
## the tier 1 pool, and its tier is saved.
func test_a_tier_1_run_starts_from_the_tier_1_pool() -> void:
	var data: RunData = RunData.from_data(_playable_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var pool: Array[StringName] = data.pool({}, 1)
	assert_true(pool.has(&"tower_bramble_cottage") and pool.has(&"thorn_tips"))
	for run_seed: int in range(1, 41):
		var s: RunSession = RunSession.start(run_seed, "", false, pool, data, catalog, 1)
		assert_not_null(s, "seed %d at tier 1" % run_seed)
		if s == null:
			return
		assert_eq(s.tier, 1)
		assert_eq(s.to_data()["tier"], 1)
	assert_not_null(RunSession.start(1, "", false, data.pool({}, 0), data, catalog), "a tier 0 pool at tier 0")
	assert_null(RunSession.start(1, "", false, pool, data, catalog, 0), "a tier 1 pool is refused at tier 0")
	assert_false(MapAssembler.plan(7, data, 1).is_empty())


# What each tier meets, over the real files (the level designer's real packs and segments)

const Player: GDScript = preload("res://tests/run/fixtures/run_player.gd")
## Everything of tier 2 a tier 0 or tier 1 player must never meet: the creatures and the boss.
const TIER_2_UNITS: Array = [&"gleamer", &"sleepyhead", &"old_hayrick"]


## Every creature type the waves of a level send, as {id: true}.
func _creatures_in(level: LevelData) -> Dictionary:
	var out: Dictionary = {}
	for wave: WaveData in level.waves:
		for group: WaveGroup in wave.groups:
			out[group.enemy] = true
	return out


## The creatures seen over the runs of seeds 1 to count at a tier.
func _seen_at_tier(data: RunData, tier: int, count: int) -> Dictionary:
	var seen: Dictionary = {}
	for run_seed: int in range(1, count + 1):
		var level: LevelData = MapAssembler.assemble(run_seed, data, catalog, tier)
		assert_not_null(level, "seed %d at tier %d" % [run_seed, tier])
		if level != null:
			seen.merge(_creatures_in(level))
	return seen


func test_a_tier_2_player_meets_the_tier_2_creatures_and_the_others_do_not() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	for tier: int in 2:
		var seen: Dictionary = _seen_at_tier(data, tier, 120)
		for id: StringName in TIER_2_UNITS:
			assert_false(seen.has(id), "%s never shows to a tier %d player" % [id, tier])
	var seen_two: Dictionary = _seen_at_tier(data, 2, 120)
	for id: StringName in TIER_2_UNITS:
		assert_true(seen_two.has(id), "%s shows to a tier 2 player" % id)
	# The tier 1 things are still there for tier 2.
	for id: StringName in [&"mossbud", &"mistwisp", &"burrowbelly"]:
		assert_true(seen_two.has(id), "%s still shows at tier 2" % id)


func test_a_tier_2_plan_can_end_on_old_hayrick_and_a_tier_1_plan_cannot() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var bosses: Dictionary = {}
	for run_seed: int in range(1, 201):
		assert_ne(MapAssembler.plan(run_seed, data, 1)["boss"], &"old_hayrick", "seed %d at tier 1" % run_seed)
		bosses[MapAssembler.plan(run_seed, data, 2)["boss"]] = true
	assert_true(bosses.has(&"old_hayrick"))
	assert_eq(bosses.size(), 6, "all six bosses at tier 2")


## The cards offered over the first drafts of a few runs at a tier.
func _offers_seen(data: RunData, tier: int, seeds: int) -> Dictionary:
	var seen: Dictionary = {}
	for run_seed: int in range(1, seeds + 1):
		var s: RunSession = RunSession.start(run_seed, "", false, data.pool({}, tier), data, catalog, tier)
		assert_not_null(s)
		if s == null:
			continue
		var player: RefCounted = Player.new(run_seed, 0, true)
		player.rich = true
		var guard: int = 0
		while s.battle.waves_started < 5 and guard < 200000:
			for id: StringName in s.offers():
				seen[id] = true
			if not player.advance(s):
				break
			guard += 1
	return seen


func test_a_tier_2_player_is_offered_the_scarecrow_cards_and_a_tier_1_player_is_not() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var tier_one: Dictionary = _offers_seen(data, 1, 10)
	var tier_two: Dictionary = _offers_seen(data, 2, 10)
	for id: StringName in TIER_2_CARDS:
		assert_false(tier_one.has(id), "%s is never offered at tier 1" % id)
	assert_true(tier_one.has(&"tower_bramble_cottage"), "tier 1 still offers the Bramble Cottage")
	assert_true(tier_two.has(&"tower_scarecrow"), "tier 2 offers the Scarecrow")
	assert_true(tier_two.has(&"big_hat"), "tier 2 offers the Big Hat")
	assert_true(tier_two.has(&"tower_bramble_cottage"), "and keeps the Bramble Cottage")


func test_a_tier_2_run_starts_from_the_tier_2_pool() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var pool: Array[StringName] = data.pool({}, 2)
	for run_seed: int in range(1, 21):
		var s: RunSession = RunSession.start(run_seed, "", false, pool, data, catalog, 2)
		assert_not_null(s, "seed %d at tier 2" % run_seed)
		if s == null:
			return
		assert_eq(s.tier, 2)
		assert_eq(s.to_data()["tier"], 2)
	assert_null(RunSession.start(1, "", false, pool, data, catalog, 1), "a tier 2 pool is refused at tier 1")
	assert_null(RunSession.start(1, "", false, pool, data, catalog, 0), "and at tier 0")
	assert_null(RunSession.start(1, "", false, pool, data, catalog, 3), "tier 3 is beyond the two tiers of the data")


## The daily follows tiers (docs/ARCHITECTURE.md 14.8): the day's seed and the day's tier give the
## run, so players at the same tier share it, and tier 0 is exactly the daily of regions 1 to 4.
func test_the_daily_follows_its_tier() -> void:
	var data: RunData = RunData.from_data(_real_files(), catalog)
	assert_not_null(data)
	if data == null:
		return
	var differs: int = 0
	for day: String in Golden.days():
		var daily_seed: int = RunSeeds.daily_seed(day)
		var runs: Array[RunSession] = []
		for tier: int in 3:
			var s: RunSession = RunSession.start(daily_seed, day, false, data.card_ids(tier), data, catalog, tier)
			assert_not_null(s, "%s at tier %d" % [day, tier])
			if s == null:
				return
			assert_true(s.daily)
			assert_eq(s.tier, tier)
			assert_eq(s.day, day)
			var again: RunSession = RunSession.start(daily_seed, day, false, data.card_ids(tier), data, catalog, tier)
			assert_eq(JSON.stringify(again.to_data()), JSON.stringify(s.to_data()), "same inputs, same daily (%s, tier %d)" % [day, tier])
			assert_eq(JSON.stringify(again.battle.level.to_data()), JSON.stringify(s.battle.level.to_data()))
			var pool: Array = s.to_data()["pool"]
			assert_eq(pool.has("tower_scarecrow"), tier == 2, "the Scarecrow card is in the pool of tier 2 only (%s)" % day)
			assert_eq(pool.has("tower_bramble_cottage"), tier >= 1)
			runs.append(s)
		var zero: RunSession = RunSession.start(daily_seed, day, false, data.card_ids(), data, catalog)
		assert_eq(JSON.stringify(zero.battle.level.to_data()), JSON.stringify(runs[0].battle.level.to_data()), "the default tier is tier 0")
		assert_eq(JSON.stringify(zero.to_data()), JSON.stringify(runs[0].to_data()))
		if JSON.stringify(runs[1].battle.level.to_data()) != JSON.stringify(runs[2].battle.level.to_data()):
			differs += 1
		# A daily of tier 1 holds no tier 2 creature, and one of tier 0 holds nothing above tier 0.
		var one_seen: Dictionary = _creatures_in(runs[1].battle.level)
		for id: StringName in TIER_2_UNITS:
			assert_false(one_seen.has(id), "%s in the tier 1 daily of %s" % [id, day])
			assert_false(_creatures_in(runs[0].battle.level).has(id), "%s in the tier 0 daily of %s" % [id, day])
		for id: StringName in [&"mossbud", &"mistwisp", &"burrowbelly"]:
			assert_false(_creatures_in(runs[0].battle.level).has(id), "%s in the tier 0 daily of %s" % [id, day])
	assert_true(differs > 0, "a tier 2 daily is not always the tier 1 daily")
