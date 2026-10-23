# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## A smoke play of every real level on the real sim: one fixed, simple defense, every
## wave started from a build phase (no early calls), run to the end. It proves each
## level plays through with no script errors and is not lost in its first wave.
## It does not judge balance: the balance bots in tools/balance/ do that.
## Each level prints one line: the result, lives left and ticks (20 ticks a second at 1x).

const Files: GDScript = preload("res://tests/levels/fixtures/level_files.gd")

## Far more than any level needs: 20 minutes of wave time at 1x.
const TICK_CAP: int = 20 * 60 * Sim.TICKS_PER_SECOND
## RULES 12.5 counts 15 s for each build phase when it measures a level's length.
const BUILD_SECONDS: int = 15

var catalog: Catalog = null


func before_each() -> void:
	catalog = Files.catalog()


## The fixed defense, before every wave: fill empty spots in cell order, taking the
## level's towers in turn by spot index, while gold lasts; then take every tier 1 tower
## to tier 2 in cell order. No gates, no tier 3, no selling.
func _plan(battle: Battle) -> void:
	var spots: Array[Vector2i] = battle.level.spots
	var offered: Array[StringName] = battle.level.towers
	for i: int in spots.size():
		if battle.tower_at(spots[i]) == null:
			battle.place_tower(spots[i], offered[i % offered.size()])
	for tower: TowerState in battle.towers.duplicate():
		if tower.tier == 1:
			battle.upgrade_tower(tower.cell)


## Plays one level to the end. Returns the result with "ticks", "wave1_lives",
## "towers_at_wave1" and "refusal" (the first refused wave start, or &"").
func _play(level: LevelData) -> Dictionary:
	var battle: Battle = Battle.create(level, catalog, false, [])
	if battle == null:
		return {}
	battle.record_events = false
	var wave1_lives: int = -1
	var towers_at_wave1: int = -1
	var refusal: StringName = &""
	while battle.phase == Battle.Phase.BUILD and battle.tick < TICK_CAP:
		_plan(battle)
		if towers_at_wave1 < 0:
			towers_at_wave1 = battle.towers.size()
		var started: StringName = battle.start_next_wave()
		if started != Battle.DONE:
			refusal = started
			break
		while battle.phase == Battle.Phase.WAVE and battle.tick < TICK_CAP:
			battle.step()
		if wave1_lives < 0:
			wave1_lives = battle.lives
	var out: Dictionary = battle.result()
	out["phase"] = battle.phase
	out["ticks"] = battle.tick
	out["wave1_lives"] = wave1_lives
	out["towers_at_wave1"] = towers_at_wave1
	out["refusal"] = refusal
	out["waves"] = battle.wave_count()
	return out


func test_every_level_plays_to_the_end_with_a_simple_defense() -> void:
	for id: String in Files.campaign_order():
		var level: LevelData = Files.level(id, catalog)
		assert_not_null(level, "%s loads" % id)
		if level == null:
			continue
		var out: Dictionary = _play(level)
		assert_false(out.is_empty(), "%s: Battle.create gives a battle" % id)
		if out.is_empty():
			continue
		var phase: int = out["phase"]
		var ticks: int = out["ticks"]
		assert_eq(out["refusal"], &"", "%s: every wave starts from its build phase" % id)
		assert_true(phase == Battle.Phase.WON or phase == Battle.Phase.LOST, "%s: the battle ends within %d ticks" % [id, TICK_CAP])
		assert_true(int(out["towers_at_wave1"]) >= 1, "%s: starting gold builds a tower" % id)
		assert_true(int(out["wave1_lives"]) > 0, "%s: the simple defense survives wave 1" % id)
		if phase == Battle.Phase.WON:
			assert_eq(out["waves_cleared"], out["waves"], "%s: a win clears every wave" % id)
		var wave_seconds: float = float(ticks) / Sim.TICKS_PER_SECOND
		var length_minutes: float = (wave_seconds + BUILD_SECONDS * int(out["waves"])) / 60.0
		print("    %s: %s, %d lives left, %d of %d waves cleared, %d ticks (%.1f s of waves at 1x, %.1f min with %d s per build phase)" % [
			id, "won" if phase == Battle.Phase.WON else "lost", int(out["lives_left"]), int(out["waves_cleared"]),
			int(out["waves"]), ticks, wave_seconds, length_minutes, BUILD_SECONDS])
