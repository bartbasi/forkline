# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Grumblesack's summons (RULES 6.3) and the release rules they follow (RULES 6.2).

const Fx: GDScript = preload("res://tests/sim/fixtures/sim_fixtures.gd")


## Steps until the phase leaves WAVE, logging [tick, event] pairs and the boss's
## step at the end of each tick.
func _log(b: Battle, limit: int = 2000) -> Array:
	var out: Array = []
	var ran: int = 0
	while b.phase == Battle.Phase.WAVE and ran < limit:
		var at: int = b.tick
		b.step()
		for event: Dictionary in b.take_events():
			out.append([at, event])
		ran += 1
	return out


func _spawns(log: Array, enemy: StringName) -> Array:
	var out: Array = []
	for entry: Array in log:
		if entry[1]["kind"] == &"spawned" and entry[1]["enemy"] == enemy:
			out.append(entry)
	return out


func test_two_scamps_every_6_seconds_at_its_spot_rules_6_3() -> void:
	var catalog: Catalog = Fx.catalog()
	var b: Battle = Fx.battle(Fx.LINE_GRID, [{"strength": 110, "groups": [Fx.group("grumblesack", 1)]}], {}, catalog, true)
	b.start_next_wave()
	Fx.steps(b, 120)
	var boss: EnemyState = b.enemy_with_id(0)
	assert_eq(boss.max_health, 2200, "2000 at strength 110")
	var spot: Vector2i = boss.pos
	var step: Array = [boss.from_cell, boss.to_cell, boss.progress]
	assert_eq(b.enemies.size(), 1, "nothing before 6.0 s")
	b.take_events()
	b.step()
	var first: EnemyState = b.enemy_with_id(1)
	assert_eq(first.type, &"scamp")
	assert_eq(first.wave, 0, "a summon belongs to its boss's wave")
	assert_eq(first.max_health, 44, "and uses its strength")
	assert_eq(Fx.events_of(b.take_events(), &"spawned")[0]["pos"], spot, "it appears where the boss stood")
	assert_eq(first.from_cell, step[0], "it finishes the boss's step")
	assert_eq(first.to_cell, step[1])
	var log: Array = _log(b)
	var scamps: Array = _spawns(log, &"scamp")
	var ticks: Array[int] = []
	for entry: Array in scamps:
		ticks.append(entry[0])
	# Tick 120 is already out of the log; the second Scamp of each batch comes 0.3 s later.
	assert_eq(ticks, [126, 240, 246] as Array[int])
	assert_eq(scamps[0][1]["pos"], spot, "the second Scamp appears at the same spot, though the boss moved on")
	assert_ne(scamps[1][1]["pos"], spot)
	assert_eq(scamps[1][1]["pos"], scamps[2][1]["pos"])


func test_a_begun_release_finishes_when_the_boss_falls_rules_6_2() -> void:
	var catalog: Catalog = Fx.catalog_with_enemy("grumblesack", {"health": 1})
	var b: Battle = Fx.battle(Fx.LINE_GRID, [{"groups": [Fx.group("grumblesack", 1)]}], {"start_gold": 500}, catalog)
	b.start_next_wave()
	Fx.steps(b, 121)
	assert_eq(b.enemies.size(), 2, "the batch has begun")
	b.place_tower(Vector2i(2, 1), &"sling_post")
	b.set_aim(Vector2i(2, 1), TowerState.Aim.LAST)
	b.take_events()
	var log: Array = _log(b)
	var defeated_at: int = -1
	for entry: Array in log:
		if entry[1]["kind"] == &"defeated" and entry[1]["enemy"] == &"grumblesack":
			defeated_at = entry[0]
	assert_eq(defeated_at, 121, "the boss falls between its two Scamps")
	var scamps: Array = _spawns(log, &"scamp")
	assert_eq(scamps.size(), 1, "one more Scamp, and no later batch")
	assert_eq(scamps[0][0], 126, "the second Scamp still comes")
	assert_eq(scamps[0][1]["pos"], Sim.center(Vector2i(3, 0)) + Vector2i(0, 120 * 400), "at the batch's spot")


func test_a_begun_release_finishes_when_the_boss_gets_through_rules_6_2() -> void:
	# A batch every 17 s with the second Scamp 1 s later: the boss gets through on
	# tick 349, between the batch at 340 and its second Scamp at 360.
	var catalog: Catalog = Fx.catalog_with_enemy("grumblesack", {"summon": {"enemy": "scamp", "count": 2, "every_ms": 17000, "gap_ms": 1000}})
	var b: Battle = Fx.battle(Fx.LINE_GRID, [{"groups": [Fx.group("grumblesack", 1)]}], {}, catalog, true)
	b.start_next_wave()
	var log: Array = _log(b)
	var leaked_boss: int = -1
	for entry: Array in log:
		if entry[1]["kind"] == &"leaked" and entry[1]["enemy"] == &"grumblesack":
			leaked_boss = entry[0]
	assert_eq(leaked_boss, 349)
	var ticks: Array[int] = []
	for entry: Array in _spawns(log, &"scamp"):
		ticks.append(entry[0])
	assert_eq(ticks, [340, 360] as Array[int])
	var cleared: int = -1
	for entry: Array in log:
		if entry[1]["kind"] == &"wave_cleared":
			cleared = entry[0]
	assert_true(cleared > 360, "the wave waits for the release to finish")
	assert_eq(b.phase, Battle.Phase.WON)
	assert_eq(b.lives, 40 - 20 - 2)


func test_released_walkers_take_their_own_route_rules_6_2_and_7_3() -> void:
	# On the fork the boss walks west (tie break). A Scamp released on the boss's step
	# finishes that step, then follows the shortest open route from there.
	var catalog: Catalog = Fx.catalog()
	var b: Battle = Fx.battle(Fx.FORK_GRID, [{"groups": [Fx.group("grumblesack", 1)]}], {}, catalog, true)
	b.start_next_wave()
	Fx.steps(b, 121)
	var scamp: EnemyState = b.enemy_with_id(1)
	var seen: Array[Vector2i] = []
	while b.enemy_with_id(1) != null:
		if not seen.has(scamp.to_cell):
			seen.append(scamp.to_cell)
		b.step()
	assert_true(seen.has(Vector2i(1, 5)), "the west branch")
	assert_eq(seen.back(), Vector2i(3, 9), "to the base")


func test_summons_count_for_their_wave_rules_4_9() -> void:
	var catalog: Catalog = Fx.catalog()
	var b: Battle = Fx.battle(Fx.LINE_GRID, [{"groups": [Fx.group("grumblesack", 1)]}, {"groups": [Fx.group("pip", 1)]}], {}, catalog, true)
	b.start_next_wave()
	Fx.steps(b, 127)
	# Boss bounty 100 plus two Scamps at 5: half of 110.
	assert_eq(b.next_wave_info()["bonus"], 55)
