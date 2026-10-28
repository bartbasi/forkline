# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## The tier 0 golden test (docs/ARCHITECTURE.md 14.13, RULES 14.9). A tier 0 run is exactly
## the run of regions 1 to 4. tests/run/fixtures/tier0_golden.json was recorded with the
## build before the expansion: the plan and a SHA-256 of the level for run seeds 1 to 200
## and for the daily seeds of 30 days from 2026-10-28, and the card pools. Only a
## deliberate change to tier 0 runs, recorded by the DM, may record it again.

const Golden: GDScript = preload("res://tests/run/fixtures/run_golden.gd")

var _golden: Dictionary = {}
var _now: Dictionary = {}


func before_each() -> void:
	var got: Dictionary = JsonFile.read(Golden.GOLDEN_PATH, 1048576)
	assert_eq(got["status"], JsonFile.OK_STATUS, "the golden file reads")
	if got["status"] == JsonFile.OK_STATUS:
		_golden = got["data"]
	_now = Golden.compute()


func test_the_golden_file_holds_what_the_test_pins() -> void:
	assert_eq((_golden["runs"] as Dictionary).size(), Golden.SEEDS)
	assert_eq((_golden["dailies"] as Dictionary).size(), Golden.DAYS)
	assert_eq((_golden["dailies"] as Dictionary).keys()[0], Golden.FIRST_DAY)
	assert_eq(Golden.days().size(), Golden.DAYS)
	assert_eq(Golden.days()[0], Golden.FIRST_DAY)
	assert_eq(Golden.days()[29], "2026-11-26")
	assert_eq((_golden["card_ids"] as Array).size(), 34)
	assert_eq((_golden["pool_none"] as Array).size(), 22)
	assert_eq(_golden["pool_every"], _golden["card_ids"])


func test_the_pools_at_tier_0_are_unchanged() -> void:
	assert_eq(_now["pool_none"], _golden["pool_none"], "pool with no unlocks")
	assert_eq(_now["pool_every"], _golden["pool_every"], "pool with every unlock")
	assert_eq(_now["card_ids"], _golden["card_ids"], "card_ids")


func test_runs_for_seeds_1_to_200_are_unchanged() -> void:
	var runs: Dictionary = _golden["runs"]
	var now: Dictionary = _now["runs"]
	for key: String in runs.keys():
		var want: Dictionary = runs[key]
		var got: Dictionary = now.get(key, {})
		assert_eq(got.get("plan", {}), want["plan"], "plan of seed %s" % key)
		assert_eq(got.get("hash", ""), want["hash"], "level of seed %s" % key)


func test_the_dailies_of_30_days_are_unchanged() -> void:
	var dailies: Dictionary = _golden["dailies"]
	var now: Dictionary = _now["dailies"]
	for day: String in dailies.keys():
		var want: Dictionary = dailies[day]
		var got: Dictionary = now.get(day, {})
		assert_eq(got.get("seed", -1), want["seed"], "seed of %s" % day)
		assert_eq(got.get("plan", {}), want["plan"], "plan of %s" % day)
		assert_eq(got.get("hash", ""), want["hash"], "level of %s" % day)


func test_a_tier_0_start_gives_the_golden_level_too() -> void:
	# RunSession.start with the default tier builds the same level as the golden file pins.
	var cat: Catalog = Golden.catalog()
	var data: RunData = RunData.from_data(Golden.real_files(), cat)
	assert_not_null(data)
	if data == null:
		return
	for run_seed: int in [1, 77, 200]:
		var s: RunSession = RunSession.start(run_seed, "", false, data.pool({}), data, cat)
		assert_not_null(s, "seed %d" % run_seed)
		if s != null:
			assert_eq(JSON.stringify(s.battle.level.to_data()).sha256_text(), _golden["runs"][str(run_seed)]["hash"])
