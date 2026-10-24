# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Runs MapView through real frames, which the synchronous test runner cannot, so every
## _draw() body of src/render/ runs and any script error shows. tests/render/test_frames.gd
## starts this script in a second Godot process and reads what it prints:
##
##     godot --headless --path . --script res://tests/render/frames_checks.gd
##
## Every problem prints a line starting with "FAIL". The exit code is 0 when nothing failed.

const Fx: GDScript = preload("res://tests/render/render_fixtures.gd")
const WATCHDOG_SECONDS: float = 120.0
const FRAMES_PER_LEVEL: int = 240

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		print("FAIL watchdog: the checks did not finish")
		quit(2))
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL %s" % message)


func _run() -> void:
	for id: String in Fx.REGION_1:
		for size: Vector2i in [Fx.COVER, Fx.INNER]:
			await _play(id, size)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _play(id: String, size: Vector2i) -> void:
	var host: SubViewport = SubViewport.new()
	host.size = size
	host.transparent_bg = false
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	var b: Battle = Fx.battle(id)
	var view: MapView = MapView.new()
	host.add_child(view)
	view.setup(b)
	var landscape: bool = size.x * 3 > size.y * 2
	var rect: Rect2 = Rect2(24, 60, float(size.y) * 0.5, float(size.y) - 120.0) if landscape else Rect2(0, 236, float(size.x), float(size.x) / 7.0 * float(b.level.rows))
	view.fit(rect)
	Fx.defend(b)
	view.show_routes(b.routes(b.closed_cells()))
	view.show_range(b.level.spots[0], 300, true)
	view.show_selection(b.level.spots[1])
	view.show_hint(b.level.spots[0])
	for i: int in 3:
		await process_frame
		view.sync(0.0)
	var bakes: int = view.ground_bakes()
	check(bakes <= 2, "%s %s: the map is drawn once, or twice when fit() asked for a sharper one" % [id, size])
	view.show_routes([])
	view.show_range(Vector2i(-1, -1), 0, false)
	Fx.fast_forward(b, b.level.waves.size() / 2)
	b.start_next_wave()
	var clock: BattleClock = BattleClock.new()
	clock.speed = 3
	var seen_shots: int = 0
	var seen_sparks: int = 0
	var worst_sync: int = 0
	for i: int in FRAMES_PER_LEVEL:
		if b.phase == Battle.Phase.WAVE:
			for t: int in clock.advance(1.0 / 60.0):
				b.step()
		else:
			clock.reset()
			if b.waves_started < b.level.waves.size():
				b.start_next_wave()
		var events: Array[Dictionary] = b.take_events()
		view.sync(clock.alpha())
		view.play_events(events)
		await process_frame
		seen_shots = maxi(seen_shots, view.projectile_count())
		seen_sparks = maxi(seen_sparks, view.sparkles().bursts)
		worst_sync = maxi(worst_sync, view.last_sync_usec)
		check(view.creature_count() == b.enemies.size(), "%s %s frame %d: a node for each creature" % [id, size, i])
	check(seen_shots > 0, "%s %s: projectiles flew" % [id, size])
	check(seen_sparks > 0, "%s %s: creatures puffed into sparkles" % [id, size])
	check(view.ground_bakes() == bakes, "%s %s: the map was not drawn again while playing" % [id, size])
	check(view.ground_draws() >= 1 and view.ground_draws() <= bakes, "%s %s: ground draw count %d" % [id, size, view.ground_draws()])
	view.fit(Rect2(0, 0, 500, 900))
	await process_frame
	host.queue_free()
	await process_frame
