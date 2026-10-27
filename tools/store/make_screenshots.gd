# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Renders a few real screens of the app at phone size for the Google Play listing and
## writes them to docs/store/graphics/. It runs the real App (src/ui/app.gd) inside a
## SubViewport, with the bundled data, a throwaway save folder and the sound off.
## It needs a rendering display, so run it without --headless, from the repo root:
##     godot --path . --script res://tools/store/make_screenshots.gd
## Optional: -- --only=front_door (one screen, by the name in SCREENS).
## It opens a window for about a minute and exits 0 when every file is written.
## Nothing here ships in the APK, and it never touches the player's real saves.
##
## Size: 1080 x 2160, the tallest shape Play accepts (twice as tall as wide). The
## picture is 24 bit PNG with no see-through pixels.

const OUT_DIR: String = "res://docs/store/graphics"
const SIZE: Vector2i = Vector2i(1080, 2160)
## A small top inset, as a phone's camera cutout would leave.
const SAFE: Rect2 = Rect2(0.0, 72.0, 1080.0, 2088.0)
const SAVE_DIR: String = "user://store_shots/"
const LEVEL: StringName = &"r1_l2"
const SCREENS: Array[String] = ["front_door", "modes", "levels", "build", "wave"]
## The stars shown on the level list: level id to star bits.
const STARS: Dictionary[StringName, int] = {&"r1_l1": 7, &"r1_l2": 7, &"r1_l3": 7, &"r1_l4": 7, &"r1_l5": 1}
## How many waves are played out of sight before the pictures are taken.
const WAVE_AT: int = 4
const WAVE_SECONDS: float = 25.0
## Gold given before each round of building, for the picture only.
const SHOT_GOLD: int = 700
## The gold the HUD shows in the pictures, set after the building.
const SHOWN_GOLD: int = 140

var _only: String = ""
var _host: SubViewport
var _app: App
var _audio: AudioService
var _failed: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("make_screenshots.gd needs a display. Run it without --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_wipe()
	await _start_app()
	if _wants("front_door"):
		await _shoot("screen_1_front_door.png")
	_app.open_mode()
	await _frames(6)
	if _wants("modes"):
		await _shoot("screen_2_modes.png")
	_app.campaign_requested.emit()
	await _frames(6)
	if _wants("levels"):
		await _shoot("screen_3_levels.png")
	if _wants("build") or _wants("wave"):
		await _battle()
	_app.queue_free()
	_audio.queue_free()
	_host.queue_free()
	await _frames(2)
	_wipe()
	quit(1 if _failed > 0 else 0)


func _wants(screen_name: String) -> bool:
	return _only.is_empty() or _only == screen_name


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


## The real App on the bundled data. Saves go to a folder of their own, and the sound is off.
func _start_app() -> void:
	_host = SubViewport.new()
	_host.size = SIZE
	_host.disable_3d = true
	_host.transparent_bg = false
	_host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_host)
	_audio = AudioService.new()
	_audio.set_enabled(false)
	root.add_child(_audio)
	_app = (load("res://scenes/ui/app.tscn") as PackedScene).instantiate() as App
	_app.game = GameData.load_from("res://data")
	_app.store = SaveStore.new(SAVE_DIR)
	_app.audio = _audio
	_app.date_source = func() -> Dictionary: return {"year": 2026, "month": 10, "day": 24}
	_app.seed_source = func() -> int: return 1234
	_host.add_child(_app)
	await _frames(3)
	_app.apply_layout(Vector2(SIZE), SAFE)
	for id: StringName in STARS:
		_app.progress.record_level(id, STARS[id])
	for id: StringName in _app.game.catalog.tower_ids():
		_app.progress.mark_seen(id)
	for id: StringName in _app.game.catalog.enemy_ids():
		_app.progress.mark_seen(id)
	_app.save_progress()
	await _frames(6)


## The Fork: a few waves played out of sight with a real defense, then the build phase
## with route lines, then a wave in progress.
func _battle() -> void:
	_app.start_level(LEVEL, false)
	await _frames(4)
	var screen: BattleScreen = _app.battle_screen()
	if screen == null:
		printerr("The battle did not start.")
		_failed += 1
		return
	var b: Battle = screen.battle
	_spend(screen)
	if not b.level.sockets.is_empty():
		b.place_gate(b.level.sockets[0])
	while b.waves_started < WAVE_AT and b.phase == Battle.Phase.BUILD:
		b.start_next_wave()
		var guard: int = 0
		while b.phase == Battle.Phase.WAVE and guard < 20000:
			b.step()
			guard += 1
		b.take_events()
		if b.phase == Battle.Phase.BUILD:
			_spend(screen)
	screen.close_context()
	b.gold = SHOWN_GOLD
	await _frames(8)
	if _wants("build"):
		await _shoot("screen_4_build_phase.png")
	if not _wants("wave") or b.phase != Battle.Phase.BUILD:
		return
	b.start_next_wave()
	screen.clock.speed = 2
	# Look at every frame of the wave and keep the busiest one: creatures on the road, shots
	# in the air and sparkles from beaten creatures.
	var best: Image = null
	var best_score: int = -1
	var started: int = Time.get_ticks_usec()
	while b.phase == Battle.Phase.WAVE:
		await RenderingServer.frame_post_draw
		var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
		if elapsed > WAVE_SECONDS:
			break
		var map: MapView = screen.map_view
		var score: int = mini(b.enemies.size(), 6) + 3 * mini(map.projectile_count(), 5) + mini(map.sparkles().active_count(), 4)
		if b.enemies.size() >= 3 and map.projectile_count() >= 2 and score > best_score:
			best_score = score
			best = _host.get_texture().get_image()
	if best == null:
		printerr("No frame of the wave showed shots in the air.")
		_failed += 1
		return
	print("wave picture score: %d" % best_score)
	_save(best, "screen_5_wave.png")


## Builds and upgrades through the screen's own panels. The gold is topped up first, so the
## picture shows a full defense and the creatures walk the whole road. The gold is only for
## the picture: it is not how a level is played.
func _spend(screen: BattleScreen) -> void:
	var b: Battle = screen.battle
	b.gold = maxi(b.gold, SHOT_GOLD)
	var types: Array[StringName] = b.level.towers
	var n: int = 0
	for cell: Vector2i in b.level.spots:
		if b.tower_at(cell) == null:
			if _build(screen, cell, types[n % types.size()]):
				n += 1
		else:
			screen.tap_at(cell)
			if screen.tower_panel.is_open() and b.tower_at(cell).tier == 1:
				screen.tower_panel.upgrade()
	screen.close_context()


## The same steps a player takes: tap the spot, pick the tower, confirm.
func _build(screen: BattleScreen, cell: Vector2i, type: StringName) -> bool:
	screen.tap_at(cell)
	if screen.context_panel() != screen.build_panel:
		return false
	screen.build_panel.select_tower(type)
	screen.build_panel.confirm()
	return screen.battle.tower_at(cell) != null


func _shoot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	_save(_host.get_texture().get_image(), file_name)


func _save(img: Image, file_name: String) -> void:
	img.convert(Image.FORMAT_RGB8)
	var path: String = OUT_DIR.path_join(file_name)
	var err: Error = img.save_png(path)
	print("%s %dx%d: %s" % [path, img.get_width(), img.get_height(), error_string(err)])
	if err != OK:
		_failed += 1


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	for file_name: String in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR + file_name)
	DirAccess.remove_absolute(SAVE_DIR)
