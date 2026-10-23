# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Towers in battle: reload, targeting modes, damage, armor, bubbles, splash, slows and
## the tier 3 paths of the Sling Post and Pumpkin Catapult (RULES 5.2 to 5.4, 6.2, 8).

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")
const ALL_TOWERS: Array = ["sling_post", "pumpkin_catapult", "lullaby_bell", "longbow_loft", "firework_tower", "bakery"]

var catalog: Catalog = null


func before_each() -> void:
	catalog = Fx.catalog()


func _battle(groups: Array, stats: Catalog = null) -> Battle:
	return Fx.battle(Fx.LINE_GRID, [{"groups": groups}], {"start_gold": 5000, "towers": ALL_TOWERS}, stats if stats != null else catalog)


## Steps n ticks, logging [tick, event] pairs.
func _log(b: Battle, n: int) -> Array:
	var out: Array = []
	for i: int in n:
		if b.phase != Battle.Phase.WAVE:
			break
		var at: int = b.tick
		b.step()
		for event: Dictionary in b.take_events():
			out.append([at, event])
	return out


func _of(log: Array, kind: StringName) -> Array:
	var out: Array = []
	for entry: Array in log:
		if entry[1]["kind"] == kind:
			out.append(entry)
	return out


func test_a_new_tower_fires_at_once_and_keeps_its_rate_rules_5_2() -> void:
	var b: Battle = _battle([Fx.group("shellback", 1)])
	b.place_tower(Vector2i(2, 1), &"sling_post")
	b.start_next_wave()
	b.take_events()
	var fired: Array = _of(_log(b, 40), &"fired")
	var ticks: Array[int] = []
	for entry: Array in fired:
		ticks.append(entry[0])
	# Reload 0.5 s at 1x: the timer runs 5000 a tick from 0; leftover is kept.
	assert_eq(ticks, [0, 9, 19, 29, 39] as Array[int])
	var event: Dictionary = fired[0][1]
	assert_eq(event, {"kind": &"fired", "cell": Vector2i(2, 1), "tower": &"sling_post", "spec": -1, "targets": [0] as Array[int], "at": [Sim.center(Vector2i(3, 0)) + Vector2i(0, 700)] as Array[Vector2i]})


func test_an_idle_tower_never_saves_up_shots_rules_5_2() -> void:
	var b: Battle = _battle([Fx.group("scamp", 1, 3000)])
	b.place_tower(Vector2i(2, 6), &"sling_post")
	b.start_next_wave()
	var log: Array = _log(b, 400)
	var fired: Array = _of(log, &"fired")
	assert_true(fired.size() >= 3)
	for k: int in range(1, fired.size()):
		assert_true(fired[k][0] - fired[k - 1][0] >= 9, "never two shots within one reload")
	assert_true(b.tower_at(Vector2i(2, 6)).reload >= 0)


func test_targeting_first_last_strong_rules_8_2() -> void:
	# Pip, Scamp, Pip, half a second apart. At tick 40 all three are in reach of [2, 3].
	var expected: Dictionary = {TowerState.Aim.FIRST: 0, TowerState.Aim.LAST: 2, TowerState.Aim.STRONG: 1}
	for aim: TowerState.Aim in expected.keys():
		var b: Battle = _battle([Fx.group("pip", 1, 0), Fx.group("scamp", 1, 500), Fx.group("pip", 1, 1000)])
		b.start_next_wave()
		Fx.steps(b, 40)
		b.place_tower(Vector2i(2, 3), &"sling_post")
		b.set_aim(Vector2i(2, 3), aim)
		b.take_events()
		b.step()
		var fired: Array[Dictionary] = Fx.events_of(b.take_events(), &"fired")
		assert_eq(fired.size(), 1)
		assert_eq(fired[0]["targets"], [expected[aim]] as Array[int], "aim %d" % aim)


func test_targeting_ties_go_to_the_lower_id_rules_8_2() -> void:
	for aim: TowerState.Aim in [TowerState.Aim.FIRST, TowerState.Aim.LAST, TowerState.Aim.STRONG]:
		var b: Battle = _battle([Fx.group("scamp", 1), Fx.group("scamp", 1)])
		b.place_tower(Vector2i(2, 1), &"sling_post")
		b.set_aim(Vector2i(2, 1), aim)
		b.start_next_wave()
		b.take_events()
		b.step()
		assert_eq(Fx.events_of(b.take_events(), &"fired")[0]["targets"], [0] as Array[int], "aim %d tie" % aim)


func test_strong_ties_go_by_first_rules_8_2() -> void:
	var b: Battle = _battle([Fx.group("scamp", 2, 0, 500), Fx.group("pip", 1, 1000)])
	b.start_next_wave()
	Fx.steps(b, 40)
	b.place_tower(Vector2i(2, 3), &"sling_post")
	b.set_aim(Vector2i(2, 3), TowerState.Aim.STRONG)
	b.take_events()
	b.step()
	assert_eq(Fx.events_of(b.take_events(), &"fired")[0]["targets"], [0] as Array[int], "the Scamp nearer the base")


func test_only_creatures_in_reach_count_rules_5_2() -> void:
	# Reach 2.5 tiles from [2, 6]'s center: a Scamp on [3, 3] is 3.16 tiles away.
	var b: Battle = _battle([Fx.group("scamp", 1)])
	b.place_tower(Vector2i(2, 6), &"sling_post")
	b.start_next_wave()
	var log: Array = _log(b, 200)
	var first: Array = _of(log, &"fired")[0]
	var at: Vector2i = first[1]["at"][0]
	var center: Vector2i = Sim.center(Vector2i(2, 6))
	var d: Vector2i = at - center
	assert_true(d.x * d.x + d.y * d.y <= 50000 * 50000, "in reach when hit")
	var before: Vector2i = at - Vector2i(0, 1000)
	d = before - center
	assert_true(d.x * d.x + d.y * d.y > 50000 * 50000, "not in reach one tick earlier")


func test_armor_and_pierce_rules_8_3() -> void:
	var b: Battle = _battle([Fx.group("shellback", 1)])
	b.place_tower(Vector2i(2, 1), &"sling_post")
	b.place_tower(Vector2i(4, 1), &"longbow_loft")
	b.start_next_wave()
	b.step()
	# Sling Post 6 minus armor 4 is 2; the Longbow's 40 ignores armor.
	assert_eq(b.enemy_with_id(0).health, 90 - 2 - 40)
	var thick: Catalog = Fx.catalog_with_enemy("scamp", {"armor": 10})
	var t: Battle = _battle([Fx.group("scamp", 1)], thick)
	t.place_tower(Vector2i(2, 1), &"sling_post")
	t.start_next_wave()
	t.step()
	assert_eq(t.enemy_with_id(0).health, 39, "at least 1 damage gets through")


func test_stone_sling_and_quickshot_rules_5_3() -> void:
	var b: Battle = _battle([Fx.group("shellback", 1)])
	b.place_tower(Vector2i(2, 1), &"sling_post")
	b.upgrade_tower(Vector2i(2, 1))
	b.upgrade_tower(Vector2i(2, 1), 1)
	b.start_next_wave()
	b.step()
	assert_eq(b.enemy_with_id(0).health, 90 - 16, "Stone Sling: 20 minus armor 4")
	var q: Battle = _battle([Fx.group("shellback", 1)])
	q.place_tower(Vector2i(2, 1), &"sling_post")
	q.upgrade_tower(Vector2i(2, 1))
	q.upgrade_tower(Vector2i(2, 1), 0)
	q.start_next_wave()
	q.take_events()
	var ticks: Array[int] = []
	for entry: Array in _of(_log(q, 20), &"fired"):
		ticks.append(entry[0])
	assert_eq(ticks, [0, 3, 7, 11, 15, 19] as Array[int], "Quickshot fires 5 times a second")
	assert_eq(Fx.events_of([{"kind": &"x"}] as Array[Dictionary], &"fired").size(), 0)


func test_bubbles_block_one_hit_and_come_back_rules_6_2() -> void:
	var b: Battle = _battle([Fx.group("bubbler", 1)])
	b.place_tower(Vector2i(2, 3), &"sling_post")
	b.start_next_wave()
	var log: Array = _log(b, 140)
	var popped: Array[int] = []
	for entry: Array in _of(log, &"popped"):
		popped.append(entry[0])
	var fired: Array[int] = []
	for entry: Array in _of(log, &"fired"):
		fired.append(entry[0])
	assert_true(popped.size() >= 2, "popped twice")
	assert_eq(popped[0], fired[0], "the first hit pops the bubble")
	# The bubble is back 40 ticks (2.0 s) after it popped; the first hit from then pops it again.
	var next_pop: int = -1
	var hits_between: int = 0
	for t: int in fired:
		if t > popped[0] and t < popped[0] + 40:
			hits_between += 1
		elif t >= popped[0] + 40 and next_pop < 0:
			next_pop = t
	assert_eq(popped[1], next_pop)
	var bubbler: EnemyState = b.enemy_with_id(0)
	var expected_health: int = 50 - 6 * (fired.size() - popped.size())
	if bubbler != null:
		assert_eq(bubbler.health, expected_health, "hits that met a bubble did no damage")
	assert_eq(hits_between, 4, "quick hitters lose one hit in four (6.2)")


func test_a_bubble_back_on_the_tick_of_a_hit_blocks_it_rules_6_2() -> void:
	var b: Battle = _battle([Fx.group("bubbler", 1)])
	b.start_next_wave()
	b.step()
	var bubbler: EnemyState = b.enemy_with_id(0)
	bubbler.bubble = false
	bubbler.bubble_ticks = 1
	b.place_tower(Vector2i(2, 1), &"sling_post")
	b.take_events()
	b.step()
	assert_eq(Fx.events_of(b.take_events(), &"popped").size(), 1, "timers run before towers (8.1)")
	assert_eq(bubbler.health, 50)


func test_splash_hits_every_walker_in_the_radius_rules_8_4() -> void:
	# Scamps 15000 and 16000 sub-units behind the first: 0.75 tiles is 15000.
	var b: Battle = _battle([Fx.group("scamp", 1, 0), Fx.group("scamp", 1, 750), Fx.group("scamp", 1, 800), Fx.group("flitter", 1, 0)])
	b.start_next_wave()
	Fx.steps(b, 30)
	b.place_tower(Vector2i(2, 1), &"pumpkin_catapult")
	b.take_events()
	b.step()
	var fired: Array[Dictionary] = Fx.events_of(b.take_events(), &"fired")
	assert_eq(fired[0]["targets"], [0] as Array[int], "the Catapult never targets the Flitter")
	assert_eq(b.enemy_with_id(0).health, 26)
	# Ids: the Flitter shares tick 0 with the first Scamp, so it is id 1.
	assert_eq(b.enemy_with_id(2).health, 26, "exactly on the radius is in")
	assert_eq(b.enemy_with_id(3).health, 40, "past the radius is out")
	assert_eq(b.enemy_with_id(1).health, 30, "Catapult splash never reaches flyers (8.4)")


func test_splash_pops_each_bubble_it_reaches_rules_6_2() -> void:
	var b: Battle = _battle([Fx.group("bubbler", 1), Fx.group("bubbler", 1), Fx.group("scamp", 1)])
	b.place_tower(Vector2i(2, 1), &"pumpkin_catapult")
	b.start_next_wave()
	b.take_events()
	b.step()
	var events: Array[Dictionary] = b.take_events()
	assert_eq(Fx.events_of(events, &"popped").size(), 2)
	assert_eq([b.enemy_with_id(0).health, b.enemy_with_id(1).health, b.enemy_with_id(2).health], [50, 50, 26])


func test_prize_pumpkin_rules_5_4() -> void:
	var b: Battle = _battle([Fx.group("scamp", 1, 0), Fx.group("scamp", 1, 1250), Fx.group("scamp", 1, 1300)])
	b.start_next_wave()
	Fx.steps(b, 40)
	b.place_tower(Vector2i(2, 3), &"pumpkin_catapult")
	b.upgrade_tower(Vector2i(2, 3))
	b.upgrade_tower(Vector2i(2, 3), 0)
	b.step()
	# 50 damage, splash 1.25 tiles (25000): the second Scamp is 25000 behind, the third 26000.
	assert_null(b.enemy_with_id(0), "50 damage pops a Scamp")
	assert_null(b.enemy_with_id(1))
	assert_eq(b.enemy_with_id(2).health, 40)


func test_jam_pot_slows_what_it_damages_rules_8_5() -> void:
	var b: Battle = _battle([Fx.group("shellback", 1), Fx.group("bubbler", 1)])
	b.place_tower(Vector2i(2, 1), &"pumpkin_catapult")
	b.upgrade_tower(Vector2i(2, 1))
	b.upgrade_tower(Vector2i(2, 1), 1)
	b.start_next_wave()
	b.step()
	var shell: EnemyState = b.enemy_with_id(0)
	var bubbler: EnemyState = b.enemy_with_id(1)
	assert_eq([shell.slow_pct, shell.slow_ticks], [40, 60], "40% for 3.0 s")
	assert_eq([bubbler.slow_pct, bubbler.slow_ticks], [0, 0], "a bubble blocks the slow too")
	assert_eq(b.enemy_numbers(0)["speed"], 42)
	var before: int = shell.progress
	b.step()
	assert_eq(shell.progress - before, 420, "speed 0.7 at 60%")
	assert_eq(shell.slow_ticks, 59)
	assert_eq(b.enemy_numbers(0)["slow_ms"], 2950)


func test_slow_slot_rules_8_5() -> void:
	var b: Battle = _battle([Fx.group("scamp", 1)])
	b.start_next_wave()
	b.step()
	var e: EnemyState = b.enemy_with_id(0)
	b._slow(e, 40, 60)
	b._slow(e, 30, 200)
	assert_eq([e.slow_pct, e.slow_ticks], [40, 60], "a weaker slow changes nothing")
	b._slow(e, 40, 80)
	assert_eq([e.slow_pct, e.slow_ticks], [40, 80], "an equal one keeps the longer time")
	b._slow(e, 40, 10)
	assert_eq([e.slow_pct, e.slow_ticks], [40, 80])
	b._slow(e, 60, 20)
	assert_eq([e.slow_pct, e.slow_ticks], [60, 20], "a stronger one replaces it")
	Fx.steps(b, 20)
	assert_eq([e.slow_pct, e.slow_ticks], [0, 0], "it runs out")


func test_flyers_and_kinds_rules_6_5() -> void:
	var b: Battle = _battle([Fx.group("flitter", 1)])
	b.place_tower(Vector2i(2, 1), &"pumpkin_catapult")
	b.place_tower(Vector2i(4, 1), &"sling_post")
	b.start_next_wave()
	b.take_events()
	b.step()
	var fired: Array[Dictionary] = Fx.events_of(b.take_events(), &"fired")
	assert_eq(fired.size(), 1)
	assert_eq(fired[0]["tower"], &"sling_post", "only the Sling Post hits flyers")
	assert_eq(b.enemy_with_id(0).health, 24)


func test_a_defeated_creature_is_not_targeted_again_rules_8_1() -> void:
	var b: Battle = _battle([Fx.group("pip", 1)])
	for cell: Vector2i in [Vector2i(2, 1), Vector2i(4, 1)]:
		b.place_tower(cell, &"sling_post")
		b.upgrade_tower(cell)
		b.upgrade_tower(cell, 1)
	b.start_next_wave()
	b.take_events()
	b.step()
	var events: Array[Dictionary] = b.take_events()
	assert_eq(Fx.events_of(events, &"fired").size(), 1, "the second tower finds nothing")
	assert_eq(b.tower_at(Vector2i(4, 1)).reload, 0, "and waits at 0")
	var defeated: Array[Dictionary] = Fx.events_of(events, &"defeated")
	assert_eq(defeated.size(), 1)
	assert_eq(defeated[0], {"kind": &"defeated", "id": 0, "enemy": &"pip", "pos": Sim.center(Vector2i(3, 0)) + Vector2i(0, 1200), "gold": 2})


func test_bells_and_bakeries_do_nothing_yet_rules_5_5_and_5_8_phase_7() -> void:
	# Bell and Bakery effects come in phase 7. They can be built and sold but do not act.
	var b: Battle = _battle([Fx.group("scamp", 1)])
	assert_eq(b.place_tower(Vector2i(2, 1), &"lullaby_bell"), Battle.DONE)
	assert_eq(b.place_tower(Vector2i(4, 1), &"bakery"), Battle.DONE)
	b.start_next_wave()
	Fx.steps(b, 10)
	assert_eq(b.enemy_with_id(0).slow_pct, 0)
	assert_eq(b.tower_numbers(Vector2i(2, 1))["slow_pct"], 35)
	assert_eq(b.tower_numbers(Vector2i(4, 1))["boost_pct"], 15)
