# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Catalog checks for the creature rules of regions 5 and 6 (docs/ARCHITECTURE.md 14.4):
## regrow, mist, dazzle, nap and dig, with their limits and combinations.

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")
const Cx: GDScript = preload("res://tests/sim/fixtures/creature_fixtures.gd")


## Problems with one creature's fields changed; a null value removes the key.
func _problems_with(id: String, changes: Dictionary) -> PackedStringArray:
	var files: Array = Cx.stats_files()
	for item: Dictionary in files[1]["enemies"]:
		if item["id"] == id:
			for key: String in changes:
				if changes[key] == null:
					item.erase(key)
				else:
					item[key] = changes[key]
	return Catalog.check(files[0], files[1], files[2])


func _ok(id: String, changes: Dictionary, what: String) -> void:
	var problems: PackedStringArray = _problems_with(id, changes)
	assert_true(problems.is_empty(), "%s loads: %s" % [what, str(problems)])


func _bad(id: String, changes: Dictionary, what: String) -> void:
	assert_false(_problems_with(id, changes).is_empty(), "%s is refused" % what)


func test_the_creatures_load_with_their_numbers_rules_6_1_and_6_3() -> void:
	var cat: Catalog = Cx.catalog()
	assert_not_null(cat, "the test catalog loads")
	if cat == null:
		return
	var moss: EnemyType = cat.enemy(&"mossbud")
	assert_eq([moss.health, moss.speed, moss.bounty, moss.regrow, moss.regrow_ms], [80, 80, 10, 4, 1000], "Mossbud")
	assert_true(cat.enemy(&"mistwisp").mist, "Mistwisp")
	assert_true(cat.enemy(&"gleamer").dazzle, "Gleamer")
	assert_eq(cat.enemy(&"sleepyhead").nap_ms, 2000, "Sleepyhead")
	var belly: EnemyType = cat.enemy(&"burrowbelly")
	assert_eq([belly.dig_first_ms, belly.dig_every_ms, belly.dig_ms], [6000, 8000, 2000], "Burrowbelly digs")
	assert_eq(belly.summon, {"enemy": &"mistwisp", "count": 2, "every_ms": 8000, "gap_ms": 300}, "and brings Mistwisps")
	var hay: EnemyType = cat.enemy(&"old_hayrick")
	assert_true(hay.dazzle and hay.nap_ms == 3000, "Old Hayrick")
	var scamp: EnemyType = cat.enemy(&"scamp")
	assert_eq([scamp.regrow, scamp.regrow_ms, scamp.mist, scamp.dazzle, scamp.nap_ms, scamp.dig_first_ms, scamp.dig_every_ms, scamp.dig_ms],
		[0, 0, false, false, 0, 0, 0, 0], "an older creature holds none of them")
	assert_not_null(Fx.catalog(), "the real files still load")


func test_regrow_and_its_limits() -> void:
	_ok("mossbud", {"regrow": 1, "regrow_ms": 50}, "the lowest regrow")
	_ok("mossbud", {"regrow": 10000, "regrow_ms": 600000}, "the highest regrow")
	_bad("mossbud", {"regrow": 0}, "regrow 0")
	_bad("mossbud", {"regrow": 10001}, "regrow 10,001")
	_bad("mossbud", {"regrow_ms": 0}, "regrow_ms 0")
	_bad("mossbud", {"regrow_ms": 600050}, "regrow_ms 600,050")
	_bad("mossbud", {"regrow_ms": 1010}, "regrow_ms off the tick")
	_bad("mossbud", {"regrow": 1.5}, "a regrow that is not whole")
	_bad("mossbud", {"regrow_ms": null}, "regrow without regrow_ms")
	_bad("mossbud", {"regrow": null}, "regrow_ms without regrow")
	_ok("mossbud", {"regrow": null, "regrow_ms": null}, "neither")
	_ok("flitter", {"regrow": 2, "regrow_ms": 500}, "a flyer that regrows")


func test_mist_and_dazzle_are_true_or_false() -> void:
	for key: String in ["mist", "dazzle"]:
		_ok("scamp", {key: false}, "%s false" % key)
		_ok("flitter", {key: true}, "%s on a flyer" % key)
		for bad: Variant in [1, 0, "true", [], {}]:
			_bad("scamp", {key: bad}, "%s = %s" % [key, str(bad)])


func test_nap_and_its_limits() -> void:
	_ok("sleepyhead", {"nap_ms": 50}, "the shortest nap")
	_ok("sleepyhead", {"nap_ms": 60000}, "the longest nap")
	_bad("sleepyhead", {"nap_ms": 0}, "nap_ms 0")
	_bad("sleepyhead", {"nap_ms": 60050}, "nap_ms 60,050")
	_bad("sleepyhead", {"nap_ms": 1010}, "nap_ms off the tick")
	_bad("sleepyhead", {"nap_ms": "2000"}, "nap_ms as text")


func test_dig_and_its_limits() -> void:
	_ok("burrowbelly", {"dig_first_ms": 50, "dig_every_ms": 100, "dig_ms": 50}, "the lowest dig")
	_ok("burrowbelly", {"dig_first_ms": 600000, "dig_every_ms": 600000, "dig_ms": 60000}, "the highest dig")
	_bad("burrowbelly", {"dig_first_ms": 0}, "dig_first_ms 0")
	_bad("burrowbelly", {"dig_first_ms": 600050}, "dig_first_ms 600,050")
	_bad("burrowbelly", {"dig_every_ms": 0}, "dig_every_ms 0")
	_bad("burrowbelly", {"dig_every_ms": 600050}, "dig_every_ms 600,050")
	_bad("burrowbelly", {"dig_ms": 0}, "dig_ms 0")
	_bad("burrowbelly", {"dig_ms": 60050, "dig_every_ms": 600000}, "dig_ms 60,050")
	_bad("burrowbelly", {"dig_ms": 1010}, "dig_ms off the tick")
	_bad("burrowbelly", {"dig_ms": 8000}, "dig_ms equal to dig_every_ms")
	_ok("burrowbelly", {"dig_ms": 7950}, "dig_ms just below dig_every_ms")
	_bad("burrowbelly", {"dig_ms": null}, "dig without dig_ms")
	_bad("burrowbelly", {"dig_first_ms": null}, "dig without dig_first_ms")
	_bad("burrowbelly", {"dig_every_ms": null}, "dig without dig_every_ms")
	_bad("burrowbelly", {"dig_first_ms": null, "dig_every_ms": null}, "dig_ms alone")
	_ok("burrowbelly", {"dig_first_ms": null, "dig_every_ms": null, "dig_ms": null}, "no dig")
	_ok("scamp", {"dig_first_ms": 1000, "dig_every_ms": 3000, "dig_ms": 1000}, "a walker that digs")
	_bad("flitter", {"dig_first_ms": 1000, "dig_every_ms": 3000, "dig_ms": 1000}, "a flyer that digs")


func test_unknown_creature_keys_are_still_refused() -> void:
	_bad("mossbud", {"regrow_at": 20}, "a save key in the stat file")
	_bad("sleepyhead", {"napped": false}, "napped in the stat file")
