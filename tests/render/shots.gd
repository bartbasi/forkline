# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Makes a screenshot of each region 1 level mid-wave, at the Fold5 cover screen size
## (portrait layout) and the inner screen size (landscape layout), by driving a real Battle
## from the level data with a simple fixed defense. Needs a display, so no --headless:
##
##     godot --path . --script res://tests/render/shots.gd -- --out=<folder>
##
## The pictures go to the folder given with --out (use a scratch folder, not the repo).
## Optional: --level=r1_l4 for one level, --size=cover or --size=inner for one screen,
## --build (the build phase with a gate, route lines, range, selection and hint), --wave=N (0 based wave to start from), --min=N creatures needed, --wait=S seconds, --tag=name.

const Fx: GDScript = preload("res://tests/render/render_fixtures.gd")
const MAX_SECONDS: float = 40.0

var _out: String = ""
var _only_level: String = ""
var _only_size: String = ""
var _theme: Theme
var _wave: int = -1
var _tag: String = ""
var _min: int = 6
var _wait: float = 0.0
var _build: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--level="):
			_only_level = arg.trim_prefix("--level=")
		elif arg.begins_with("--size="):
			_only_size = arg.trim_prefix("--size=")
		elif arg.begins_with("--wave="):
			_wave = int(arg.trim_prefix("--wave="))
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--min="):
			_min = int(arg.trim_prefix("--min="))
		elif arg == "--build":
			_build = true
		elif arg.begins_with("--wait="):
			_wait = float(arg.trim_prefix("--wait="))
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _out.is_empty():
		printerr("shots.gd needs a display and --out=<folder>.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_theme = UiTheme.build()
	for id: String in Fx.REGION_1:
		if not _only_level.is_empty() and id != _only_level:
			continue
		if _only_size.is_empty() or _only_size == "cover":
			await _shoot(id, Fx.COVER, "cover")
		if _only_size.is_empty() or _only_size == "inner":
			await _shoot(id, Fx.INNER, "inner")
	quit(0)


func _shoot(id: String, size: Vector2i, label: String) -> void:
	var host: SubViewport = SubViewport.new()
	host.size = size
	host.transparent_bg = false
	host.disable_3d = true
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	var screen: Control = Control.new()
	screen.size = Vector2(size)
	screen.theme = _theme
	host.add_child(screen)
	var back: Backdrop = Backdrop.new()
	screen.add_child(back)
	var b: Battle = Fx.battle(id)
	var view: MapView = MapView.new()
	screen.add_child(view)
	view.setup(b)
	var landscape: bool = size.y < int(1.5 * float(size.x))
	var rect: Rect2
	var note: Label = Label.new()
	screen.add_child(note)
	if landscape:
		var h: float = float(size.y) - 120.0
		rect = Rect2(40, 60, h * 7.0 / float(b.level.rows), h)
		note.position = Vector2(rect.end.x + 60.0, 80.0)
	else:
		var w: float = float(size.x)
		rect = Rect2(0, 236, w, w / 7.0 * float(b.level.rows))
		note.position = Vector2(40.0, 90.0)
	view.fit(rect)
	Fx.defend(b)
	if _build:
		if not b.level.sockets.is_empty():
			b.place_gate(b.level.sockets[0])
		view.show_routes(b.routes(b.closed_cells()))
		view.show_range(b.level.spots[0], 300, false)
		view.show_selection(b.level.spots[1])
		view.show_hint(b.level.spots[2])
		for i: int in 20:
			await process_frame
			view.sync(0.0)
		note.text = "%s   build phase   gold %d" % [b.level.name, b.gold]
		await RenderingServer.frame_post_draw
		var shot: Image = host.get_texture().get_image()
		var shot_path: String = _out.path_join("%s_%s_build.png" % [id, label])
		print("%s: %s" % [shot_path, error_string(shot.save_png(shot_path))])
		host.queue_free()
		await process_frame
		return
	var wave: int = _wave if _wave >= 0 else maxi(b.level.waves.size() - 4, 1)
	Fx.fast_forward(b, wave)
	b.start_next_wave()
	var clock: BattleClock = BattleClock.new()
	clock.speed = 2
	var last: int = Time.get_ticks_usec()
	var started: int = last
	var frames: PackedFloat32Array = PackedFloat32Array()
	var ready_frames: int = 0
	while true:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = float(now - last) / 1000000.0
		last = now
		frames.append(dt)
		if b.phase == Battle.Phase.WAVE:
			for t: int in clock.advance(dt):
				b.step()
		var events: Array[Dictionary] = b.take_events()
		view.sync(clock.alpha())
		view.play_events(events)
		note.text = "%s   wave %d of %d   lives %d   gold %d" % [b.level.name, b.waves_started, b.wave_count(), b.lives, b.gold]
		var elapsed: float = float(now - started) / 1000000.0
		if b.waves_started < b.wave_count() and b.next_wave_info()["refusal"] == &"":
			b.start_next_wave()
		if elapsed >= _wait and b.enemies.size() >= _min and (_min < 6 or (view.projectile_count() >= 1 and view.sparkles().active_count() >= 1)):
			ready_frames += 1
		if ready_frames >= 2 or elapsed > MAX_SECONDS or b.phase == Battle.Phase.WON or b.phase == Battle.Phase.LOST:
			break
	await RenderingServer.frame_post_draw
	var img: Image = host.get_texture().get_image()
	var path: String = _out.path_join("%s_%s%s.png" % [id, label, _tag])
	var err: Error = img.save_png(path)
	print("%s %dx%d creatures=%d projectiles=%d sparkle_emitters=%d bake=%.2f: %s" % [path, img.get_width(), img.get_height(), b.enemies.size(), view.projectile_count(), view.sparkles().active_count(), view.bake_scale(), error_string(err)])
	host.queue_free()
	await process_frame
