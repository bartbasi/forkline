# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Time per tick in the largest region 1 crowd: two waves of 120 on the map at once
## (the spawn bound and max_waves_running), seven tier 3 towers, a boss with summons
## (docs/ARCHITECTURE.md 9.1, 9.2). The budget on the dev PC, headless, is 0.5 ms a tick.
## The assert is looser so a busy machine does not fail the suite; the printed numbers
## are what the report uses.

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")
const Tx: GDScript = preload("res://tests/sim/fixtures/tower_fixtures.gd")
const Cx: GDScript = preload("res://tests/sim/fixtures/creature_fixtures.gd")

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


## The expansion towers on the same road: pulses, lines, frights and a lured flock,
## beside today's towers (docs/ARCHITECTURE.md 14.12). Attacking towers stay at tier 1,
## so the crowd lives long enough to measure.
func test_time_per_tick_with_the_expansion_towers() -> void:
	var waves: Array = [
		{"strength": 1000, "groups": [Fx.group("pip", 45, 0, 50), Fx.group("scamp", 30, 0, 50), Fx.group("shellback", 15, 0, 100),
			Fx.group("flitter", 30, 0, 100)]},
		{"strength": 400, "groups": [Fx.group("puffball", 30, 0, 100)]},
	]
	var catalog: Catalog = Tx.catalog()
	var b: Battle = Fx.battle(PAIRS_GRID, waves, {"start_gold": 100000, "towers": Tx.ALL}, catalog, true)
	assert_not_null(b)
	var plan: Array = [
		[Vector2i(0, 1), &"moth_lantern"], [Vector2i(1, 1), &"bakery"],
		[Vector2i(4, 1), &"bramble_cottage"], [Vector2i(5, 1), &"snow_fort"],
		[Vector2i(1, 3), &"scarecrow"], [Vector2i(2, 3), &"bramble_cottage"],
		[Vector2i(5, 3), &"lullaby_bell"], [Vector2i(6, 3), &"snow_fort"],
		[Vector2i(0, 5), &"moth_lantern"], [Vector2i(1, 5), &"pumpkin_catapult"],
		[Vector2i(4, 5), &"scarecrow"], [Vector2i(5, 5), &"snow_fort"],
		[Vector2i(1, 7), &"bramble_cottage"], [Vector2i(2, 7), &"longbow_loft"],
		[Vector2i(5, 7), &"sling_post"], [Vector2i(6, 7), &"moth_lantern"],
	]
	for item: Array in plan:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE)
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	var low: int = 0
	while b.phase == Battle.Phase.WAVE and b.tick < 4000:
		if b.waves_started == 1 and b.next_wave_info()["refusal"] == &"":
			b.start_next_wave()
		var start: int = Time.get_ticks_usec()
		b.step()
		var spent: int = Time.get_ticks_usec() - start
		b.take_events()
		if b.enemies.size() >= 120:
			times.append(spent)
			low = maxi(low, b._low_list.size())
		peak = maxi(peak, b.enemies.size())
	assert_true(peak >= 120, "peak %d live creatures" % peak)
	assert_true(low > 0, "flyers were lured low in the crowd")
	assert_true(times.size() >= 100, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: expansion towers, %d ticks with 120 or more creatures, peak %d, up to %d low: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, low, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)


## Level 2-2 (Sleepy Mill) as the balance analyst's most crowded case, waves 9 and 10 with
## the bot's five towers and its gate, wave 10 called as soon as it may be: about 115 live
## creatures, the case the Fold5 measured on 2026-10-27 (docs/render/perf-fold5-2026-10-27.md).
const MILL_GRID: Array = [
	".1.....",
	".#.o...",
	".#G###.",
	".#o#.#.",
	".G.#o#.",
	".#o#.#o",
	".###.#.",
	"....o#.",
	".#####.",
	".#oG.o.",
	".###...",
	"...B...",
]


func test_time_per_tick_in_the_level_2_2_crowd() -> void:
	var waves: Array = [
		{"strength": 135, "groups": [Fx.group("skitter", 20, 0, 450), Fx.group("scamp", 40, 8000, 100), Fx.group("flitter", 10, 12000, 400)]},
		{"strength": 115, "groups": [Fx.group("pip", 56, 0, 50), Fx.group("skitter", 16, 5000, 500), Fx.group("flitter", 8, 9000, 400)]},
	]
	var b: Battle = Fx.battle(MILL_GRID, waves, {"start_gold": 10000, "gates": 1, "towers": ["sling_post", "pumpkin_catapult", "lullaby_bell"]})
	assert_not_null(b)
	for item: Array in [[Vector2i(3, 1), &"sling_post", 1], [Vector2i(2, 3), &"lullaby_bell", 2], [Vector2i(2, 5), &"pumpkin_catapult", 1],
			[Vector2i(4, 7), &"sling_post", 2], [Vector2i(5, 9), &"sling_post", 2]]:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE)
		if item[2] == 2:
			assert_eq(b.upgrade_tower(item[0]), Battle.DONE)
	assert_eq(b.place_gate(Vector2i(2, 2)), Battle.DONE)
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	while b.phase == Battle.Phase.WAVE and b.tick < 4000:
		if b.waves_started == 1 and b.next_wave_info()["refusal"] == &"":
			b.start_next_wave()
		var start: int = Time.get_ticks_usec()
		b.step()
		var spent: int = Time.get_ticks_usec() - start
		b.take_events()
		if b.enemies.size() >= 100:
			times.append(spent)
		peak = maxi(peak, b.enemies.size())
	assert_true(peak >= 100, "peak %d live creatures" % peak)
	assert_true(times.size() >= 50, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: level 2-2 crowd, %d ticks with 100 or more creatures, peak %d: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)


## The creatures of regions 7 and 8 in a crowd on the same road: growers, Yawners dozing
## the towers, Blinkers, the most Hootlings a wave brings (RULES 12.5) under Bells, and
## both bosses, against the expansion towers and today's (docs/ARCHITECTURE.md 14.12).
## Attacking towers stay at tier 1, so the crowd lives long enough to measure.
func test_time_per_tick_with_the_creatures_of_regions_7_and_8() -> void:
	var waves: Array = [
		{"strength": 1000, "groups": [Fx.group("snowroller", 30, 0, 50), Fx.group("blinker", 30, 0, 50), Fx.group("yawner", 14, 0, 100),
			Fx.group("hootling", 6, 0, 500), Fx.group("pip", 25, 0, 50), Fx.group("flitter", 15, 0, 100)]},
		{"strength": 400, "groups": [Fx.group("snowsnore", 1), Fx.group("glimmertoad", 1, 500), Fx.group("hootling", 6, 0, 300),
			Fx.group("snowroller", 30, 0, 100), Fx.group("blinker", 30, 0, 100)]},
	]
	var catalog: Catalog = Cx.catalog()
	var b: Battle = Fx.battle(PAIRS_GRID, waves, {"start_gold": 100000, "towers": Tx.ALL}, catalog, true)
	assert_not_null(b)
	var plan: Array = [
		[Vector2i(0, 1), &"moth_lantern"], [Vector2i(1, 1), &"lullaby_bell"],
		[Vector2i(4, 1), &"bramble_cottage"], [Vector2i(5, 1), &"snow_fort"],
		[Vector2i(1, 3), &"scarecrow"], [Vector2i(2, 3), &"sling_post"],
		[Vector2i(5, 3), &"lullaby_bell"], [Vector2i(6, 3), &"snow_fort"],
		[Vector2i(0, 5), &"pumpkin_catapult"], [Vector2i(1, 5), &"bakery"],
		[Vector2i(4, 5), &"lullaby_bell"], [Vector2i(5, 5), &"bramble_cottage"],
		[Vector2i(1, 7), &"longbow_loft"], [Vector2i(2, 7), &"lullaby_bell"],
		[Vector2i(5, 7), &"sling_post"], [Vector2i(6, 7), &"firework_tower"],
	]
	for item: Array in plan:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE)
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	var kinds: Dictionary = {}
	var awake: int = 0
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
			for e: EnemyState in b.enemies:
				awake += 1 if e.awake else 0
		peak = maxi(peak, b.enemies.size())
	assert_true(kinds.has(&"yawned") and kinds.has(&"blinked"), "yawns and blinks happened: %s" % str(kinds.keys()))
	assert_true(awake > 0, "creatures were kept awake in the crowd")
	assert_true(peak >= 150, "peak %d live creatures" % peak)
	assert_true(times.size() >= 100, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: regions 7 and 8 crowd, %d ticks with 150 or more creatures, peak %d: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)


## Every map feature with room for 23 towers: entrance 1 through the tunnel and under the
## bridge to the stumps, entrance 2 over the bridge and down the slide (Fx.FEATURE_GRID
## with more build spots).
const FEATURE_CROWD_GRID: Array = [
	"o..1...",
	"o.oT.oo",
	".o.T.o.",
	"2##X##.",
	"o.o#ov.",
	".o.#ov.",
	"o.oP.#o",
	".o.#o#.",
	"o.o#.#o",
	".o.#.P.",
	"o.o#.G.",
	"...###.",
	"....B..",
]


## The crowded case of docs/ARCHITECTURE.md 14.12: about 200 live over two waves, with
## Mistwisps, Hootlings, Yawners, Mossbuds, Gleamers, a lured flock and a digging
## Burrowbelly, on a map with a tunnel, a bridge, a slide and stumps, against Bramble
## Cottages, Snow Forts, Scarecrows, Moth Lanterns and today's towers. Attacking towers
## stay at tier 1, so the crowd lives long enough to measure. The bar is the other cases':
## a mean under 2 ms a tick on the dev PC.
func test_time_per_tick_in_the_crowded_expansion_case() -> void:
	var waves: Array = [
		{"strength": 1000, "groups": [Fx.group("mossbud", 36, 0, 50), Fx.group("gleamer", 20, 0, 100, 2), Fx.group("yawner", 12, 0, 150),
			Fx.group("mistwisp", 6, 0, 300, 2), Fx.group("hootling", 6, 0, 300), Fx.group("flitter", 26, 0, 100, 2)]},
		{"strength": 600, "groups": [Fx.group("burrowbelly", 1), Fx.group("mossbud", 36, 0, 50, 2), Fx.group("gleamer", 16, 0, 100),
			Fx.group("yawner", 10, 0, 150, 2), Fx.group("mistwisp", 6, 0, 300), Fx.group("hootling", 6, 0, 300, 2), Fx.group("flitter", 26, 0, 100)]},
	]
	var catalog: Catalog = Cx.catalog()
	var b: Battle = Fx.battle(FEATURE_CROWD_GRID, waves, {"start_gold": 100000, "towers": Tx.ALL}, catalog, true)
	assert_not_null(b)
	if b == null:
		return
	var plan: Array = [
		[Vector2i(2, 1), &"bramble_cottage"], [Vector2i(5, 1), &"moth_lantern"], [Vector2i(1, 2), &"snow_fort"],
		[Vector2i(5, 2), &"scarecrow"], [Vector2i(0, 1), &"lullaby_bell"], [Vector2i(6, 1), &"bakery"],
		[Vector2i(2, 4), &"bramble_cottage"], [Vector2i(4, 4), &"snow_fort"], [Vector2i(4, 5), &"moth_lantern"],
		[Vector2i(1, 5), &"pumpkin_catapult"], [Vector2i(2, 6), &"scarecrow"], [Vector2i(6, 6), &"sling_post"],
		[Vector2i(4, 7), &"bramble_cottage"], [Vector2i(2, 8), &"snow_fort"], [Vector2i(6, 8), &"moth_lantern"],
		[Vector2i(1, 9), &"longbow_loft"], [Vector2i(2, 10), &"firework_tower"], [Vector2i(0, 8), &"lullaby_bell"],
	]
	for item: Array in plan:
		assert_eq(b.place_tower(item[0], item[1]), Battle.DONE, "%s at %s" % [item[1], item[0]])
	b.start_next_wave()
	var times: Array[int] = []
	var peak: int = 0
	var kinds: Dictionary = {}
	var low: int = 0
	var hidden: int = 0
	var away: int = 0
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
			low = maxi(low, b._low_list.size())
			for e: EnemyState in b.enemies:
				hidden += 1 if e.hidden else 0
				away += 1 if e.out_of_reach else 0
		peak = maxi(peak, b.enemies.size())
	for kind: StringName in [&"burrowed", &"yawned"]:
		assert_true(kinds.has(kind), "%s happened: %s" % [kind, str(kinds.keys())])
	assert_true(low > 0, "flyers were lured low in the crowd")
	assert_true(hidden > 0, "creatures hid in the mist in the crowd")
	assert_true(away > 0, "creatures were out of reach in the crowd")
	assert_true(peak >= 180, "peak %d live creatures" % peak)
	assert_true(times.size() >= 100, "%d ticks measured" % times.size())
	var total: int = 0
	for t: int in times:
		total += t
	var sorted: Array[int] = times.duplicate()
	sorted.sort()
	var mean: int = total / maxi(times.size(), 1)
	var p99: int = sorted[mini(sorted.size() - 1, sorted.size() * 99 / 100)]
	print("    sim: crowded expansion case, %d ticks with 150 or more creatures, peak %d, up to %d low: mean %d us, 99th percentile %d us, max %d us per tick" % [times.size(), peak, low, mean, p99, sorted.back()])
	assert_true(mean < 2000, "mean %d us per tick" % mean)
