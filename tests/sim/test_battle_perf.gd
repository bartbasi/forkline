# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Time per tick in the largest region 1 crowd: two waves of 120 on the map at once
## (the spawn bound and max_waves_running), seven tier 3 towers, a boss with summons
## (docs/ARCHITECTURE.md 9.1, 9.2). The budget on the dev PC, headless, is 0.5 ms a tick.
## The assert is looser so a busy machine does not fail the suite; the printed numbers
## are what the report uses.

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")

## A long serpentine road, 41 steps, 11 rows and 7 spots, like the largest region 1 maps.
const SNAKE_GRID: Array = [
	"1######",
	"o..o..#",
	"#######",
	"#..o..o",
	"#######",
	"o..o..#",
	"#######",
	"#..o...",
	"#######",
	"......#",
	"......B",
]


func test_time_per_tick_in_the_largest_region_1_crowd() -> void:
	var waves: Array = [
		{"groups": [Fx.group("pip", 60, 0, 50), Fx.group("scamp", 40, 0, 100), Fx.group("flitter", 20, 0, 150)]},
		{"groups": [Fx.group("grumblesack", 1), Fx.group("scamp", 100, 0, 50), Fx.group("pip", 19, 0, 100)]},
	]
	var catalog: Catalog = Fx.catalog()
	var b: Battle = Fx.battle(SNAKE_GRID, waves, {"start_gold": 10000, "strength": 1000}, catalog, true)
	assert_not_null(b)
	var plan: Array = [
		[Vector2i(0, 1), &"sling_post", 0], [Vector2i(3, 1), &"pumpkin_catapult", 0],
		[Vector2i(3, 3), &"pumpkin_catapult", 1], [Vector2i(6, 3), &"sling_post", 1],
		[Vector2i(0, 5), &"sling_post", 0], [Vector2i(3, 5), &"pumpkin_catapult", 0],
		[Vector2i(3, 7), &"sling_post", 0],
	]
	for item: Array in plan:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE)
		b.upgrade_tower(item[0])
		assert_eq(b.upgrade_tower(item[0], item[2]), Battle.DONE)
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	while b.phase == Battle.Phase.WAVE and b.tick < 3000:
		if b.waves_started == 1 and b.next_wave_info()["refusal"] == &"":
			b.start_next_wave()
		var start: int = Time.get_ticks_usec()
		b.step()
		var spent: int = Time.get_ticks_usec() - start
		b.take_events()
		if b.enemies.size() >= 150:
			times.append(spent)
		peak = maxi(peak, b.enemies.size())
	assert_true(peak >= 200, "peak %d live creatures" % peak)
	assert_true(times.size() >= 100, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: %d ticks with 150 or more creatures, peak %d: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)


## A serpentine road past 16 spots in pairs, so Bakeries have neighbours to boost.
const PAIRS_GRID: Array = [
	"1######",
	"oo..oo#",
	"#######",
	"#oo..oo",
	"#######",
	"oo..oo#",
	"#######",
	"#oo..oo",
	"#######",
	"......#",
	"......B",
]


func test_time_per_tick_with_bells_bakeries_menders_and_splits() -> void:
	# Wave 0 is a sturdy crowd with Menders and flyers; wave 1, called early, brings
	# Puffballs that split. Every tower kind and path that adds work per tick stands.
	var waves: Array = [
		{"strength": 1000, "groups": [Fx.group("pip", 55, 0, 50), Fx.group("scamp", 40, 0, 50), Fx.group("mender", 15, 0, 100), Fx.group("flitter", 10, 0, 100)]},
		{"strength": 100, "groups": [Fx.group("puffball", 30, 0, 100)]},
	]
	var catalog: Catalog = Fx.catalog()
	var all: Array = ["sling_post", "pumpkin_catapult", "lullaby_bell", "longbow_loft", "firework_tower", "bakery"]
	var b: Battle = Fx.battle(PAIRS_GRID, waves, {"start_gold": 100000, "towers": all}, catalog, true)
	assert_not_null(b)
	var plan: Array = [
		[Vector2i(0, 1), &"sling_post", 0], [Vector2i(1, 1), &"bakery", 0],
		[Vector2i(4, 1), &"lullaby_bell", 0], [Vector2i(5, 1), &"pumpkin_catapult", 0],
		[Vector2i(1, 3), &"bakery", 1], [Vector2i(2, 3), &"pumpkin_catapult", 1],
		[Vector2i(5, 3), &"lullaby_bell", 1], [Vector2i(6, 3), &"firework_tower", 0],
		[Vector2i(0, 5), &"longbow_loft", 1], [Vector2i(1, 5), &"bakery", 0],
		[Vector2i(4, 5), &"longbow_loft", 0], [Vector2i(5, 5), &"lullaby_bell", 0],
		[Vector2i(1, 7), &"pumpkin_catapult", 0], [Vector2i(2, 7), &"bakery", 0],
		[Vector2i(5, 7), &"sling_post", 0], [Vector2i(6, 7), &"lullaby_bell", 1],
	]
	for item: Array in plan:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE)
		# Attacking towers stay at tier 1, so the crowd lives long enough to measure.
		if b.tower_at(item[0]).kind != &"attack":
			b.upgrade_tower(item[0])
			assert_eq(b.upgrade_tower(item[0], item[2]), Battle.DONE)
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	var kinds: Dictionary = {}
	while b.phase == Battle.Phase.WAVE and b.tick < 4000:
		if b.waves_started == 1 and b.next_wave_info()["refusal"] == &"":
			b.start_next_wave()
		var start: int = Time.get_ticks_usec()
		b.step()
		var spent: int = Time.get_ticks_usec() - start
		for event: Dictionary in b.take_events():
			kinds[event["kind"]] = true
		if b.enemies.size() >= 150:
			times.append(spent)
		peak = maxi(peak, b.enemies.size())
	assert_true(kinds.has(&"healed") and kinds.has(&"released"), "heals and splits happened: %s" % str(kinds.keys()))
	assert_true(peak >= 150, "peak %d live creatures" % peak)
	assert_true(times.size() >= 100, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: support crowd, %d ticks with 150 or more creatures, peak %d: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)
