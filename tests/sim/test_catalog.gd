# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Catalog.check and from_data on the real data/stats/ files and on hostile copies
## (docs/ARCHITECTURE.md 2.6, 2.12).

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")

var files: Array = []


func before_each() -> void:
	files = Fx.stats_files()


func _problems() -> PackedStringArray:
	return Catalog.check(files[0], files[1], files[2])


func _tower(id: String) -> Dictionary:
	for item: Dictionary in files[0]["towers"]:
		if item["id"] == id:
			return item
	return {}


func _enemy(id: String) -> Dictionary:
	for item: Dictionary in files[1]["enemies"]:
		if item["id"] == id:
			return item
	return {}


func _expect_problem(what: String) -> void:
	var problems: PackedStringArray = _problems()
	assert_false(problems.is_empty(), what)
	assert_null(Catalog.from_data(files[0], files[1], files[2]), what + " gives no catalog")


func test_the_real_stat_files_load() -> void:
	var problems: PackedStringArray = _problems()
	assert_eq(problems.size(), 0, "problems: %s" % "; ".join(problems))
	var catalog: Catalog = Catalog.from_data(files[0], files[1], files[2])
	assert_not_null(catalog)
	assert_eq(catalog.tower_ids(), [&"sling_post", &"pumpkin_catapult", &"lullaby_bell", &"longbow_loft", &"firework_tower", &"bakery"])
	assert_eq(catalog.enemy_ids().size(), 15)
	assert_null(catalog.tower(&"nope"))
	assert_null(catalog.enemy(&"nope"))


func test_every_tower_field_of_2_6_is_read() -> void:
	var catalog: Catalog = Fx.catalog()
	# RULES 5.3: Sling Post tiers and paths.
	var sling: TowerType = catalog.tower(&"sling_post")
	assert_eq(sling.kind, &"attack")
	assert_eq(sling.plural, "Sling Posts")
	assert_eq(sling.specs, [&"quickshot", &"stone_sling"])
	assert_eq(sling.spec_name(1), "Stone Sling")
	assert_eq(sling.spec_info(0), "Fires twice as fast.")
	var t1: TowerStats = sling.stats(1, -1)
	assert_eq([t1.cost, t1.reach, t1.damage, t1.reload_ms, t1.splash, t1.targets], [100, 250, 6, 500, 0, 1])
	assert_true(t1.hits_ground and t1.hits_air, "Sling Post hits both")
	assert_eq(sling.stats(3, 0).reload_ms, 200)
	assert_eq(sling.stats(3, 1).damage, 20)
	assert_null(sling.stats(3, -1), "tier 3 needs a spec")
	assert_null(sling.stats(2, 0), "tier 2 takes spec -1")
	assert_null(sling.stats(4, -1))
	# RULES 5.4: Pumpkin Catapult, Jam Pot slow.
	var pumpkin: TowerType = catalog.tower(&"pumpkin_catapult")
	assert_false(pumpkin.stats(1, -1).hits_air, "Catapult cannot hit flyers")
	assert_eq(pumpkin.stats(1, -1).splash, 75)
	assert_eq(pumpkin.stats(3, 0).splash, 125)
	var jam: TowerStats = pumpkin.stats(3, 1)
	assert_eq([jam.slow_pct, jam.slow_ms, jam.reload_ms, jam.splash], [40, 3000, 1500, 100])
	# The other kinds and optional fields.
	var bell: TowerType = catalog.tower(&"lullaby_bell")
	assert_eq(bell.kind, &"slow")
	assert_true(bell.stats(3, 1).hits_air, "Night Bell reaches flyers")
	assert_eq(catalog.tower(&"longbow_loft").stats(3, 1).targets, 3)
	assert_true(catalog.tower(&"longbow_loft").stats(1, -1).pierce)
	var bakery: TowerType = catalog.tower(&"bakery")
	assert_eq(bakery.kind, &"boost")
	assert_eq(bakery.stats(3, 1).boost_damage, 2)
	assert_eq(bakery.stats(3, 0).boost_pct, 40)
	var numbers: Dictionary = t1.numbers()
	for key: String in ["damage", "reload_ms", "reach", "splash", "targets", "pierce", "slow_pct", "slow_ms", "hits_ground", "hits_air", "boost_pct", "boost_damage"]:
		assert_true(numbers.has(key), "numbers has " + key)


func test_every_creature_field_of_2_6_is_read() -> void:
	var catalog: Catalog = Fx.catalog()
	var scamp: EnemyType = catalog.enemy(&"scamp")
	assert_eq([scamp.health, scamp.armor, scamp.speed, scamp.lives, scamp.bounty], [40, 0, 100, 1, 5])
	assert_true(catalog.enemy(&"flitter").flying)
	assert_true(catalog.enemy(&"bubbler").bubble)
	var puffball: EnemyType = catalog.enemy(&"puffball")
	assert_eq([puffball.split_into, puffball.split_count, puffball.split_gap_ms], [&"puff", 3, 300])
	var mender: EnemyType = catalog.enemy(&"mender")
	assert_eq([mender.heal, mender.heal_reach, mender.heal_ms], [8, 150, 2000])
	assert_eq(catalog.enemy(&"gatecrasher").break_ms, 4000)
	var boss: EnemyType = catalog.enemy(&"grumblesack")
	assert_true(boss.boss)
	assert_eq(boss.summon, {"enemy": &"scamp", "count": 2, "every_ms": 6000, "gap_ms": 300})
	assert_eq(catalog.enemy(&"ironshell").speed_up["at_pct"], [75, 50, 25])
	assert_eq(catalog.enemy(&"ironshell").speed_up["add"], 10)
	assert_eq(catalog.enemy(&"old_tusk").release["enemy"], &"dusk_moth")
	assert_eq(catalog.enemy(&"old_tusk").release["at_pct"], 50)
	assert_eq(scamp.summon, {}, "no summon is {}")


func test_every_rule_key_is_read() -> void:
	var rules: GameRules = Fx.catalog().rules
	assert_eq([rules.start_lives, rules.relaxed_lives_pct, rules.relaxed_gold_pct, rules.refund_pct], [20, 200, 150, 70])
	assert_eq([rules.early_bonus_pct, rules.clear_bonus, rules.clear_bonus_per_wave, rules.star2_lives], [50, 20, 5, 15])
	assert_eq([rules.max_waves_running, rules.max_gates, rules.bubble_ms, rules.run_stars], [2, 3, 2000, 12])
	assert_eq(rules.region_stars, [0, 6, 12, 18])


func test_ints_and_whole_numbers_both_pass() -> void:
	_tower("sling_post")["tiers"][0]["cost"] = 100
	assert_eq(_problems().size(), 0, "an int is fine")
	_tower("sling_post")["tiers"][0]["cost"] = 100.0
	assert_eq(_problems().size(), 0, "a whole JSON number is fine")


func test_hostile_numbers_are_refused() -> void:
	for bad: Variant in [1.5, NAN, INF, -INF, "100", null, true, [], {}, 1e300, -100, 105]:
		files = Fx.stats_files()
		_tower("sling_post")["tiers"][0]["cost"] = bad
		_expect_problem("cost %s" % str(bad))


func test_unknown_and_missing_keys_are_refused() -> void:
	_tower("sling_post")["tiers"][0]["dmg"] = 6
	_expect_problem("unknown stat key")
	files = Fx.stats_files()
	_tower("sling_post")["tiers"][0].erase("reload_ms")
	_expect_problem("missing reload_ms")
	files = Fx.stats_files()
	_enemy("scamp")["colour"] = "red"
	_expect_problem("unknown creature key")
	files = Fx.stats_files()
	files[2].erase("bubble_ms")
	_expect_problem("missing rules key")
	files = Fx.stats_files()
	files[2]["extra"] = 1
	_expect_problem("unknown rules key")
	files = Fx.stats_files()
	_tower("bakery")["tiers"][0]["damage"] = 3
	_expect_problem("damage on a boost tower")


func test_ids_text_and_shapes_are_checked() -> void:
	var cases: Array[Callable] = [
		func() -> void: _tower("sling_post")["id"] = "Sling Post",
		func() -> void: _tower("sling_post")["id"] = "pumpkin_catapult",
		func() -> void: _tower("sling_post")["name"] = "",
		func() -> void: _tower("sling_post")["name"] = "A name that is far too long for it",
		func() -> void: _tower("sling_post")["info"] = "tab\there",
		func() -> void: _tower("sling_post")["info"] = "caf" + char(233),
		func() -> void: _tower("sling_post")["kind"] = "heal",
		func() -> void: _tower("sling_post")["tiers"].pop_back(),
		func() -> void: _tower("sling_post")["specs"].append({}),
		func() -> void: _tower("sling_post")["specs"][1]["id"] = "quickshot",
		func() -> void: _tower("sling_post")["tiers"][0]["hits"] = "water",
		func() -> void: _tower("sling_post")["tiers"][0]["targets"] = 4,
		func() -> void: _tower("sling_post")["tiers"][0]["reload_ms"] = 525,
		func() -> void: _tower("pumpkin_catapult")["specs"][1].erase("slow_ms"),
		func() -> void: _enemy("scamp")["health"] = 0,
		func() -> void: _enemy("scamp")["id"] = "pip",
		func() -> void: _enemy("puffball")["split_into"] = "nobody",
		func() -> void: _enemy("puffball").erase("split_gap_ms"),
		func() -> void: _enemy("grumblesack")["summon"]["enemy"] = "grumblesack",
		func() -> void: _enemy("grumblesack")["summon"]["enemy"] = "puffball",
		func() -> void: _enemy("grumblesack")["summon"]["extra"] = 1,
		func() -> void: _enemy("moon_moth")["summon"]["enemy"] = "scamp",
		func() -> void: _enemy("ironshell")["speed_up"]["at_pct"] = [50, 75],
		func() -> void: _enemy("old_tusk")["release"]["at_pct"] = 100,
		func() -> void: _enemy("mender").erase("heal_ms"),
		func() -> void: files[1]["format"] = 2,
		func() -> void: files[0]["towers"] = [],
		func() -> void: files[2]["region_stars"] = [6, 0],
		func() -> void: files[2]["star2_lives"] = 21,
		func() -> void: files[2]["refund_pct"] = 101,
	]
	for i: int in cases.size():
		files = Fx.stats_files()
		cases[i].call()
		_expect_problem("case %d" % i)


func test_wrong_top_level_types_never_crash() -> void:
	for bad: Variant in [null, 1, "x", [], {}, [{}], {"format": 1}]:
		assert_false(Catalog.check(bad, files[1], files[2]).is_empty(), "towers %s" % str(bad))
		assert_false(Catalog.check(files[0], bad, files[2]).is_empty(), "enemies %s" % str(bad))
		assert_false(Catalog.check(files[0], files[1], bad).is_empty(), "rules %s" % str(bad))
		assert_null(Catalog.from_data(bad, bad, bad))


func test_problem_lines_name_the_file_and_field() -> void:
	_tower("sling_post")["tiers"][1]["damage"] = 0
	var problems: PackedStringArray = _problems()
	assert_eq(problems.size(), 1)
	assert_eq(problems[0], "towers.json: towers[0].tiers[1].damage: must be 1 to 100000")
