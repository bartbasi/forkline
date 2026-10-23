# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## Forkline theme slice: a playable bit of an early level in the cozy
## storybook look, so Bart can judge it on his phone. Prototype only: the
## code is thrown away after hard stop A, and only the look carries forward.
##
## Command line options, after `--`:
##   --shot=<png>    play a scripted moment, save a screenshot, quit
##   --sheet=<png>   draw the silhouette sheet, save it, quit
##   --icon=<png>    draw the store icon idea, save it and a 48 px copy, quit
##   --font=outfit|system|both
##   --caption       add a store caption (with --shot)
##   --build         with --shot, show the build phase instead of a wave

const P := preload("res://prototypes/theme/palette.gd")
const Art := preload("res://prototypes/theme/art.gd")
const Synth := preload("res://prototypes/theme/synth.gd")
const Layer := preload("res://prototypes/theme/layer.gd")
const Showcase := preload("res://prototypes/theme/showcase.gd")
const OUTFIT: FontFile = preload("res://prototypes/theme/fonts/Outfit[wght].ttf")

const DT: float = 1.0 / 60.0
const MAP_ALONG: float = 1.4
## Window width / height at or above this uses the landscape layout.
const LANDSCAPE_MIN_ASPECT: float = 0.8
const MIN_TOUCH_DP: float = 48.0
const TOUCH_UNITS: float = 150.0
const MARGIN: float = 24.0
const GAP: float = 14.0
const TOWER_SIZE: float = 0.1
## Room kept above the map, in map units, for tall towers and the dusk sky.
const HEADROOM: float = 0.16
const CAPTION_H: float = 300.0

# Rough tier 1 numbers in map units (the map is 1.0 across). Prototype only.
const TOWER_COST: PackedInt32Array = [60, 90, 70, 110, 80, 70]
const TOWER_RANGE: PackedFloat32Array = [0.26, 0.24, 0.2, 0.5, 0.32, 0.22]
const TOWER_DAMAGE: PackedFloat32Array = [4.0, 9.0, 1.0, 24.0, 3.0, 0.0]
const TOWER_RELOAD: PackedFloat32Array = [0.35, 1.7, 1.3, 2.2, 0.9, 0.0]
const TOWER_SHOT_SPEED: PackedFloat32Array = [1.6, 0.0, 0.0, 3.2, 1.0, 0.0]
## Height of the muzzle above the tower's base, in tower sizes.
const TOWER_MUZZLE: PackedFloat32Array = [1.0, 0.6, 0.0, 2.0, 1.3, 0.0]
const SPLASH_RADIUS: float = 0.09
const SLOW_FACTOR: float = 0.5
const SLOW_TIME: float = 1.6
const BOOST: float = 1.3
const ENEMY_HP: PackedFloat32Array = [30.0, 16.0, 70.0, 7.0]
const ENEMY_SPEED: PackedFloat32Array = [0.085, 0.15, 0.055, 0.11]
const ENEMY_ARMOR: PackedFloat32Array = [0.0, 0.0, 3.0, 0.0]
const ENEMY_BOUNTY: PackedInt32Array = [3, 3, 6, 1]
const ENEMY_LEAK: PackedInt32Array = [1, 1, 2, 1]
const ENEMY_SIZE: PackedFloat32Array = [0.06, 0.06, 0.072, 0.04]
const WAVE_NAMES: PackedStringArray = ["Nightlings", "Nightlings and Dashers", "Nightlings and Shellbacks", "Mites and Dashers"]
const FONT_NAMES: PackedStringArray = ["Outfit", "System", "Both"]
const START_GOLD: int = 120
const START_LIVES: int = 20
const WAVE_BONUS: int = 20

enum Mode { PLAY, SHEET, ICON }
enum FontMode { OUTFIT, SYSTEM, BOTH }
enum Fx { STAR, CLOUD, TEXT, RING }


class Enemy:
	var kind: int = 0
	var route: int = 0
	var seg: int = 0
	var dist: float = 0.0
	var lateral: float = 0.0
	var hp: float = 1.0
	var max_hp: float = 1.0
	var slow_time: float = 0.0
	var phase: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.DOWN
	var face_left: bool = false
	var alive: bool = true


class Tower:
	var kind: int = 0
	var spot: int = 0
	var cooldown: float = 0.0
	var flash: float = 0.0
	var boosted: bool = false
	var aim_at: Vector2 = Vector2.ZERO
	var has_aim: bool = false


class Shot:
	var kind: int = 0
	var pos: Vector2 = Vector2.ZERO
	var target: Enemy = null
	var land: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var flight: float = 0.5
	var first_dist: float = 0.1
	var start_h: float = 0.1
	var arc: float = 0.0
	var damage: float = 1.0
	var done: bool = false


class Effect:
	var kind: int = 0
	var anchor: Vector2 = Vector2.ZERO
	var off: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var life: float = 1.0
	var size: float = 0.01
	var color: Color = Color.WHITE
	var text: String = ""


var mode: int = Mode.PLAY
var art: Art = Art.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Layers.
var bg: Node2D
var world: Node2D
var hud: Node2D

# Map, in map units: x across (0 to 1), y along the flow (0 to MAP_ALONG).
var roads: Array[PackedVector2Array] = []
var routes: Array[PackedVector2Array] = []
var route_cum: Array[PackedFloat32Array] = []
var spots: PackedVector2Array = PackedVector2Array()
var gate_pos: Vector2 = Vector2.ZERO
var gate_dir: Vector2 = Vector2.DOWN
var trees: Array[Vector3] = []
var tufts: PackedVector2Array = PackedVector2Array()
var flowers: PackedVector2Array = PackedVector2Array()
var fireflies: PackedVector2Array = PackedVector2Array()

# Game state.
var towers: Array[Tower] = []
var enemies: Array[Enemy] = []
var shots: Array[Shot] = []
var effects: Array[Effect] = []
var gold: int = START_GOLD
var lives: int = START_LIVES
var wave: int = 0
var in_wave: bool = false
var wave_clock: float = 0.0
var spawn_queue: Array = []
var hp_mult: float = 1.0
var gate_closed: bool = false
var paused: bool = false
var game_over: bool = false
var speed: int = 1
var selected_card: int = -1
var selected_spot: int = -1
var sim_t: float = 0.0
var anim_t: float = 0.0
var acc: float = 0.0
var toast_text: String = ""
var toast_time: float = 0.0
var route_flash: float = 0.0

# Layout, in viewport units.
var vs: Vector2 = Vector2(1080, 2400)
var landscape: bool = false
var flow_vertical: bool = true
var map_origin: Vector2 = Vector2.ZERO
var ms: float = 1000.0
var map_region: Rect2 = Rect2()
var sky_top: float = 0.0
var units_per_dp: float = 1.0
var touch: float = TOUCH_UNITS
var buttons: Array[Dictionary] = []
var stats_rect: Rect2 = Rect2()
var hint_rect: Rect2 = Rect2()

# Fonts.
var font_mode: int = FontMode.OUTFIT
var f_outfit_bold: FontVariation
var f_outfit: FontVariation
var f_sys_bold: SystemFont
var f_sys: SystemFont
var _styles: Dictionary = {}

# Audio.
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _music_task: int = -1
var _music_samples: PackedFloat32Array = PackedFloat32Array()
var _music_started_ms: int = 0

# Command line.
var _shot_path: String = ""
var _caption: bool = false
var _build_moment: bool = false
var _demo_label: String = ""


func _ready() -> void:
	rng.seed = 20261023
	_make_fonts()
	_read_args()
	bg = _add_layer(self, _paint_bg)
	world = _add_layer(self, _paint_world)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	hud = _add_layer(canvas, _paint_hud)
	_build_map()
	_reset_game()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	if mode != Mode.PLAY:
		_capture_showcase()
		return
	_make_audio()
	if not _shot_path.is_empty():
		_demo()
		_capture(_shot_path)


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _add_layer(parent: Node, painter: Callable) -> Node2D:
	var layer: Layer = Layer.new()
	layer.painter = painter
	parent.add_child(layer)
	return layer


func _read_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--sheet="):
			_shot_path = arg.trim_prefix("--sheet=")
			mode = Mode.SHEET
		elif arg.begins_with("--icon="):
			_shot_path = arg.trim_prefix("--icon=")
			mode = Mode.ICON
		elif arg == "--font=system":
			font_mode = FontMode.SYSTEM
		elif arg == "--font=both":
			font_mode = FontMode.BOTH
		elif arg == "--caption":
			_caption = true
		elif arg == "--build":
			_build_moment = true


# Fonts and text.

func _make_fonts() -> void:
	var wght: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	f_outfit_bold = FontVariation.new()
	f_outfit_bold.base_font = OUTFIT
	f_outfit_bold.variation_opentype = {wght: 650}
	f_outfit = FontVariation.new()
	f_outfit.base_font = OUTFIT
	f_outfit.variation_opentype = {wght: 450}
	f_sys_bold = SystemFont.new()
	f_sys_bold.font_names = PackedStringArray(["sans-serif"])
	f_sys_bold.font_weight = 700
	f_sys = SystemFont.new()
	f_sys.font_names = PackedStringArray(["sans-serif"])
	f_sys.font_weight = 400


## Font for numbers, titles and buttons.
func fb() -> Font:
	return f_sys_bold if font_mode == FontMode.SYSTEM else f_outfit_bold


## Font for hints and small labels.
func fr() -> Font:
	return f_outfit if font_mode == FontMode.OUTFIT else f_sys


func _font_name() -> String:
	return FONT_NAMES[font_mode]


func _text(ci: CanvasItem, r: Rect2, s: String, size: int, col: Color, font: Font, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var fs: int = size
	while fs > 14 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x:
		fs -= 2
	var base: float = r.position.y + (r.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(r.position.x, base), s, align, r.size.x, fs, col)


func _wrapped(ci: CanvasItem, r: Rect2, s: String, size: int, col: Color, font: Font) -> void:
	var fs: int = size
	var lines: int = 1
	while true:
		var height: float = font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs).y
		lines = maxi(1, int(round(height / font.get_height(fs))))
		if height <= r.size.y or fs <= 16:
			break
		fs -= 2
	var total: float = font.get_height(fs) * float(lines)
	var top: float = r.position.y + (r.size.y - total) * 0.5 + font.get_ascent(fs)
	ci.draw_multiline_string(font, Vector2(r.position.x, top), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, -1, col)


func _outlined(ci: CanvasItem, center: Vector2, s: String, size: int, col: Color) -> void:
	var font: Font = fb()
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = center + Vector2(-w * 0.5, (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 6), P.INK_LINE)
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _panel(ci: CanvasItem, r: Rect2, fill: Color, border: Color, radius: float, border_w: float) -> void:
	var key: String = "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), int(radius), int(border_w)]
	var sb: StyleBoxFlat = _styles.get(key, null)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(int(border_w))
		sb.set_corner_radius_all(int(radius))
		sb.shadow_color = Color(0.04, 0.02, 0.08, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		sb.anti_aliasing = true
		_styles[key] = sb
	ci.draw_style_box(sb, r)


# Audio.

func _make_audio() -> void:
	for i: int in 10:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds = {
		"shot": Synth.shot(), "lob": Synth.lob(), "puff": Synth.puff(),
		"gate_closed": Synth.gate_closed(), "gate_opened": Synth.gate_opened(),
		"build": Synth.build(), "leak": Synth.leak(), "click": Synth.click(),
	}
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	if _shot_path.is_empty():
		_music_started_ms = Time.get_ticks_msec()
		_music_task = WorkerThreadPool.add_task(_make_music)


func _make_music() -> void:
	_music_samples = Synth.music_samples()


func _poll_music() -> void:
	if _music_task < 0 or not WorkerThreadPool.is_task_completed(_music_task):
		return
	WorkerThreadPool.wait_for_task_completion(_music_task)
	_music_task = -1
	_music.stream = Synth.to_stream(_music_samples, true, Synth.MUSIC_RATE)
	_music.play()
	print("Music loop built in %.1f s (%.1f s long)." % [float(Time.get_ticks_msec() - _music_started_ms) / 1000.0, float(_music_samples.size()) / float(Synth.MUSIC_RATE)])


func _sfx(sound: String, volume_db: float = -6.0, pitch: float = 1.0, min_gap: float = 0.05) -> void:
	if _players.is_empty() or not _sounds.has(sound):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < min_gap:
		return
	_last_played[sound] = now
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * rng.randf_range(0.95, 1.05)
	player.play()


# Map.

func _build_map() -> void:
	var trunk: PackedVector2Array = _smooth(PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.5, 0.12), Vector2(0.5, 0.22)]))
	var branch_a: PackedVector2Array = _smooth(PackedVector2Array([
		Vector2(0.5, 0.22), Vector2(0.36, 0.30), Vector2(0.22, 0.42), Vector2(0.18, 0.58),
		Vector2(0.24, 0.74), Vector2(0.38, 0.86), Vector2(0.5, 0.94)]))
	var branch_b: PackedVector2Array = _smooth(PackedVector2Array([
		Vector2(0.5, 0.22), Vector2(0.66, 0.28), Vector2(0.82, 0.36), Vector2(0.84, 0.50),
		Vector2(0.66, 0.58), Vector2(0.62, 0.70), Vector2(0.80, 0.78), Vector2(0.70, 0.90), Vector2(0.5, 0.94)]))
	var tail: PackedVector2Array = _smooth(PackedVector2Array([Vector2(0.5, 0.94), Vector2(0.5, 1.08), Vector2(0.5, 1.30)]))
	roads = [trunk, branch_a, branch_b, tail]
	routes = [_join(trunk, branch_a, tail), _join(trunk, branch_b, tail)]
	route_cum = [_cumulative(routes[0]), _cumulative(routes[1])]
	# The gate socket sits on the short branch.
	var cum_a: PackedFloat32Array = _cumulative(branch_a)
	var target: float = cum_a[cum_a.size() - 1] * 0.42
	for i: int in range(1, branch_a.size()):
		if cum_a[i] >= target:
			gate_pos = branch_a[i - 1].lerp(branch_a[i], (target - cum_a[i - 1]) / maxf(0.0001, cum_a[i] - cum_a[i - 1]))
			gate_dir = (branch_a[i] - branch_a[i - 1]).normalized()
			break
	# Six towers at tier 1 on their spots, plus two empty spots.
	spots = PackedVector2Array([
		Vector2(0.50, 0.38), Vector2(0.45, 0.63), Vector2(0.07, 0.66), Vector2(0.94, 0.64),
		Vector2(0.22, 1.10), Vector2(0.38, 0.50), Vector2(0.68, 0.45), Vector2(0.78, 1.10)])
	trees = [
		Vector3(0.08, 0.15, 1), Vector3(0.92, 0.17, 0), Vector3(0.24, 0.19, 0), Vector3(0.77, 0.16, 1),
		Vector3(0.04, 0.42, 0), Vector3(0.97, 0.40, 1), Vector3(0.06, 0.92, 1), Vector3(0.95, 0.92, 0),
		Vector3(0.06, 1.14, 0), Vector3(0.95, 1.16, 1), Vector3(0.52, 0.80, 0)]
	for i: int in 260:
		var p: Vector2 = Vector2(rng.randf_range(-0.02, 1.02), rng.randf_range(0.02, MAP_ALONG))
		if _clear_of_roads(p, 0.07):
			if i % 4 == 0:
				flowers.append(p)
			else:
				tufts.append(p)
	for i: int in 16:
		fireflies.append(Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.1, 1.2)))


func _clear_of_roads(p: Vector2, margin: float) -> bool:
	for road: PackedVector2Array in roads:
		for q: Vector2 in road:
			if p.distance_to(q) < margin:
				return false
	for s: Vector2 in spots:
		if p.distance_to(s) < 0.07:
			return false
	return true


static func _smooth(ctrl: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = ctrl.size()
	for i: int in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k: int in 10:
			out.append(ctrl[i].cubic_interpolate(ctrl[i + 1], p0, p3, float(k) / 10.0))
	out.append(ctrl[n - 1])
	return out


static func _join(a: PackedVector2Array, b: PackedVector2Array, c: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = a.duplicate()
	out.append_array(b.slice(1))
	out.append_array(c.slice(1))
	return out


static func _cumulative(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	return cum


func _route_length(r: int) -> float:
	return route_cum[r][route_cum[r].size() - 1]


func _point_at(r: int, d: float) -> Vector2:
	var cum: PackedFloat32Array = route_cum[r]
	var i: int = clampi(cum.bsearch(d), 1, cum.size() - 1)
	var pts: PackedVector2Array = routes[r]
	return pts[i - 1].lerp(pts[i], clampf((d - cum[i - 1]) / maxf(0.0001, cum[i] - cum[i - 1]), 0.0, 1.0))


# Map to screen.

func m2s(p: Vector2) -> Vector2:
	if flow_vertical:
		return map_origin + p * ms
	return map_origin + Vector2(p.y, p.x) * ms


func m2s_dir(d: Vector2) -> Vector2:
	return d if flow_vertical else Vector2(d.y, d.x)


func _map_rect() -> Rect2:
	var size: Vector2 = Vector2(1.0, MAP_ALONG) if flow_vertical else Vector2(MAP_ALONG, 1.0)
	return Rect2(map_origin, size * ms)


# Layout. Portrait or landscape follows the window's shape only.

func _on_resized() -> void:
	vs = get_viewport_rect().size
	landscape = vs.x / vs.y >= LANDSCAPE_MIN_ASPECT
	var window_px: Vector2 = Vector2(DisplayServer.window_get_size())
	var px_per_unit: float = window_px.x / vs.x if vs.x > 0.0 and window_px.x > 0.0 else 1.0
	var dpi: float = float(DisplayServer.screen_get_dpi())
	units_per_dp = (dpi / 160.0) / maxf(0.01, px_per_unit)
	touch = maxf(TOUCH_UNITS, (MIN_TOUCH_DP + 2.0) * units_per_dp)
	var safe: Rect2 = Rect2(Vector2.ZERO, vs)
	if OS.has_feature("mobile"):
		var area: Rect2i = DisplayServer.get_display_safe_area()
		var a: Vector2 = Vector2(area.position) / px_per_unit
		var b: Vector2 = Vector2(area.end) / px_per_unit
		safe = Rect2(a, b - a).intersection(Rect2(Vector2.ZERO, vs))
	if _caption:
		# Room for the store caption above the game.
		safe.position.y += CAPTION_H
		safe.size.y -= CAPTION_H
	if landscape:
		_layout_landscape(safe)
	else:
		_layout_portrait(safe)
	_fit_map()
	print("Slice layout: %s, viewport %dx%d, window %dx%d px, dpi %d, map flows %s, smallest touch target %.0f units = %.0f dp" % [
		"landscape" if landscape else "portrait", int(vs.x), int(vs.y), int(window_px.x), int(window_px.y), int(dpi),
		"down" if flow_vertical else "across", touch, touch / units_per_dp])
	bg.queue_redraw()


func _layout_portrait(safe: Rect2) -> void:
	buttons.clear()
	var left: float = safe.position.x + MARGIN
	var right: float = safe.end.x - MARGIN
	var width: float = right - left
	var top: float = safe.position.y + MARGIN
	var font_w: float = maxf(touch * 1.35, 200.0)
	stats_rect = Rect2(left, top, width - font_w - GAP, touch)
	_add_button("font", Rect2(right - font_w, top, font_w, touch))
	var bottom: float = safe.end.y - MARGIN
	var row_y: float = bottom - touch
	_add_button("pause", Rect2(left, row_y, touch, touch))
	_add_button("speed", Rect2(left + touch + GAP, row_y, touch, touch))
	var start_x: float = left + 2.0 * (touch + GAP)
	_add_button("start", Rect2(start_x, row_y, right - start_x, touch))
	var card_w: float = (width - 5.0 * 10.0) / 6.0
	var card_h: float = maxf(touch * 1.35, 200.0)
	var tray_y: float = row_y - GAP - card_h
	for i: int in 6:
		_add_button("card%d" % i, Rect2(left + float(i) * (card_w + 10.0), tray_y, card_w, card_h))
	hint_rect = Rect2(left, tray_y - GAP - 104.0, width, 104.0)
	map_region = Rect2(0.0, top + touch + GAP, vs.x, hint_rect.position.y - GAP - (top + touch + GAP))
	sky_top = top + touch


func _layout_landscape(safe: Rect2) -> void:
	buttons.clear()
	var panel_w: float = clampf(vs.x * 0.26, 3.0 * touch + 2.0 * GAP + 2.0 * MARGIN + 220.0, 820.0)
	var top: float = safe.position.y + MARGIN
	var bottom: float = safe.end.y - MARGIN
	var right: float = safe.end.x - MARGIN
	var left: float = right - panel_w
	stats_rect = Rect2(left, top, panel_w, touch)
	var start_rect: Rect2 = Rect2(left, bottom - touch, panel_w, touch)
	_add_button("start", start_rect)
	var row_y: float = start_rect.position.y - GAP - touch
	_add_button("pause", Rect2(left, row_y, touch, touch))
	_add_button("speed", Rect2(left + touch + GAP, row_y, touch, touch))
	var font_x: float = left + 2.0 * (touch + GAP)
	_add_button("font", Rect2(font_x, row_y, right - font_x, touch))
	var card_w: float = (panel_w - 2.0 * GAP) / 3.0
	var card_h: float = maxf(touch * 1.35, 210.0)
	var tray_y: float = row_y - GAP - 2.0 * card_h - GAP
	for i: int in 6:
		var col: int = i % 3
		var row: int = i / 3
		_add_button("card%d" % i, Rect2(left + float(col) * (card_w + GAP), tray_y + float(row) * (card_h + GAP), card_w, card_h))
	var hint_top: float = top + touch + GAP
	hint_rect = Rect2(left, hint_top, panel_w, minf(260.0, tray_y - GAP - hint_top))
	map_region = Rect2(safe.position.x, top, left - GAP - safe.position.x, bottom - top)
	sky_top = safe.position.y


func _add_button(id: String, r: Rect2) -> void:
	buttons.append({"id": id, "rect": r})


func _button_rect(id: String) -> Rect2:
	for b: Dictionary in buttons:
		if b["id"] == id:
			return b["rect"]
	return Rect2()


func _fit_map() -> void:
	var r: Rect2 = map_region
	var s_down: float = minf(r.size.x, r.size.y / (MAP_ALONG + HEADROOM))
	var s_across: float = minf(r.size.x / MAP_ALONG, r.size.y / (1.0 + HEADROOM))
	# Portrait always flows down. Landscape picks whichever way fits bigger.
	flow_vertical = s_down >= s_across or not landscape
	ms = s_down if flow_vertical else s_across
	var size: Vector2 = Vector2(1.0, MAP_ALONG) * ms if flow_vertical else Vector2(MAP_ALONG, 1.0) * ms
	# Sit the map at the bottom of its region; the space above is dusk sky.
	map_origin = Vector2(r.position.x + (r.size.x - size.x) * 0.5, r.end.y - size.y)


# Game.

func _reset_game() -> void:
	towers.clear()
	enemies.clear()
	shots.clear()
	effects.clear()
	for kind: int in 6:
		_place_tower(kind, kind)
	gold = START_GOLD
	lives = START_LIVES
	wave = 0
	in_wave = false
	spawn_queue = []
	gate_closed = false
	game_over = false
	paused = false
	selected_card = -1
	selected_spot = -1


func _place_tower(kind: int, spot: int) -> void:
	var tw: Tower = Tower.new()
	tw.kind = kind
	tw.spot = spot
	towers.append(tw)
	for other: Tower in towers:
		other.boosted = false
		for lamp: Tower in towers:
			if lamp.kind == Art.Tower.LANTERN and lamp != other and spots[lamp.spot].distance_to(spots[other.spot]) <= TOWER_RANGE[Art.Tower.LANTERN]:
				other.boosted = true


func _tower_at(spot: int) -> Tower:
	for tw: Tower in towers:
		if tw.spot == spot:
			return tw
	return null


func _start_wave() -> void:
	wave += 1
	in_wave = true
	wave_clock = 0.0
	hp_mult = 1.0 + 0.4 * float((wave - 1) / 4)
	spawn_queue = _wave_queue(wave)
	selected_card = -1
	_toast("Wave %d: %s" % [wave, WAVE_NAMES[(wave - 1) % 4]])


func _wave_queue(n: int) -> Array:
	var q: Array = []
	match (n - 1) % 4:
		0:
			for i: int in 8:
				q.append([float(i) * 1.3, Art.Creature.BASIC])
		1:
			for i: int in 5:
				q.append([float(i) * 1.2, Art.Creature.BASIC])
			for i: int in 6:
				q.append([2.5 + float(i) * 0.8, Art.Creature.FAST])
		2:
			for i: int in 6:
				q.append([float(i) * 1.2, Art.Creature.BASIC])
			for i: int in 4:
				q.append([1.5 + float(i) * 2.4, Art.Creature.ARMORED])
		3:
			for g: int in 3:
				for i: int in 6:
					q.append([float(g) * 3.2 + float(i) * 0.2, Art.Creature.SWARM])
			for i: int in 3:
				q.append([1.6 + float(i) * 3.2, Art.Creature.FAST])
	q.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return q


func _spawn(kind: int) -> void:
	var e: Enemy = Enemy.new()
	e.kind = kind
	e.route = 1 if gate_closed else 0
	e.max_hp = ENEMY_HP[kind] * hp_mult
	e.hp = e.max_hp
	e.phase = rng.randf() * TAU
	if kind == Art.Creature.SWARM:
		e.lateral = rng.randf_range(-0.02, 0.02)
	e.pos = _point_at(e.route, 0.0)
	enemies.append(e)


func _step(dt: float) -> void:
	sim_t += dt
	if in_wave:
		wave_clock += dt
		while not spawn_queue.is_empty() and float(spawn_queue[0][0]) <= wave_clock:
			var entry: Array = spawn_queue.pop_front()
			_spawn(int(entry[1]))
	for e: Enemy in enemies:
		_move_enemy(e, dt)
	for tw: Tower in towers:
		_tower_step(tw, dt)
	for s: Shot in shots:
		_shot_step(s, dt)
	for fx: Effect in effects:
		fx.age += dt
		fx.off += fx.vel * dt
		fx.vel *= 0.96
		if fx.kind == Fx.STAR:
			fx.vel.y += 0.05 * dt
	enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive)
	shots = shots.filter(func(s: Shot) -> bool: return not s.done)
	effects = effects.filter(func(fx: Effect) -> bool: return fx.age < fx.life)
	if in_wave and spawn_queue.is_empty() and enemies.is_empty() and not game_over:
		in_wave = false
		gold += WAVE_BONUS
		_toast("Wave %d cleared. +%d gold" % [wave, WAVE_BONUS])


func _move_enemy(e: Enemy, dt: float) -> void:
	var slow: float = SLOW_FACTOR if e.slow_time > 0.0 else 1.0
	e.slow_time -= dt
	e.dist += ENEMY_SPEED[e.kind] * slow * dt
	var cum: PackedFloat32Array = route_cum[e.route]
	if e.dist >= cum[cum.size() - 1]:
		e.alive = false
		lives = maxi(0, lives - ENEMY_LEAK[e.kind])
		_sfx("leak", -6.0)
		if lives == 0:
			game_over = true
		return
	while e.seg < cum.size() - 2 and cum[e.seg + 1] < e.dist:
		e.seg += 1
	var pts: PackedVector2Array = routes[e.route]
	var a: Vector2 = pts[e.seg]
	var b: Vector2 = pts[e.seg + 1]
	e.dir = (b - a).normalized()
	var k: float = clampf((e.dist - cum[e.seg]) / maxf(0.0001, cum[e.seg + 1] - cum[e.seg]), 0.0, 1.0)
	e.pos = a.lerp(b, k) + Vector2(-e.dir.y, e.dir.x) * e.lateral
	var sx: float = m2s_dir(e.dir).x
	if absf(sx) > 0.2:
		e.face_left = sx < 0.0


func _tower_step(tw: Tower, dt: float) -> void:
	tw.flash = maxf(0.0, tw.flash - dt * 2.5)
	if tw.kind == Art.Tower.LANTERN:
		return
	tw.cooldown -= dt * (BOOST if tw.boosted else 1.0)
	if tw.cooldown > 0.0:
		return
	var base: Vector2 = spots[tw.spot]
	var reach: float = TOWER_RANGE[tw.kind]
	var target: Enemy = null
	for e: Enemy in enemies:
		if e.alive and e.pos.distance_to(base) <= reach and (target == null or e.dist > target.dist):
			target = e
	if target == null:
		return
	tw.cooldown = TOWER_RELOAD[tw.kind]
	tw.flash = 1.0
	tw.aim_at = target.pos
	tw.has_aim = true
	if tw.kind == Art.Tower.MILL:
		for e: Enemy in enemies:
			if e.alive and e.pos.distance_to(base) <= reach:
				e.slow_time = SLOW_TIME
				_hit(e, TOWER_DAMAGE[tw.kind], false)
		_effect(Fx.RING, base, Vector2.ZERO, Vector2.ZERO, 0.7, reach, P.FLOUR)
		for i: int in 8:
			var a: float = TAU * float(i) / 8.0
			_effect(Fx.STAR, base, Vector2(0, -0.06), Vector2(cos(a), sin(a) * 0.6) * 0.18, 0.8, 0.012, P.FLOUR)
		_sfx("puff", -16.0, 0.6, 0.2)
		return
	var s: Shot = Shot.new()
	s.kind = tw.kind
	s.pos = base
	s.target = target
	s.land = target.pos
	s.start_h = TOWER_MUZZLE[tw.kind] * TOWER_SIZE
	s.damage = TOWER_DAMAGE[tw.kind]
	s.first_dist = maxf(0.01, base.distance_to(target.pos))
	if tw.kind == Art.Tower.BAKE:
		s.target = null
		s.flight = 0.9
		s.arc = 0.16
		_sfx("lob", -9.0)
	elif tw.kind == Art.Tower.ROCKET:
		s.arc = 0.1
		_sfx("shot", -15.0, 1.5, 0.12)
	elif tw.kind == Art.Tower.LOOKOUT:
		_sfx("shot", -9.0, 0.55, 0.1)
	else:
		_sfx("shot", -16.0, 1.0, 0.09)
	shots.append(s)


func _shot_step(s: Shot, dt: float) -> void:
	s.age += dt
	if s.kind == Art.Tower.BAKE:
		if s.age >= s.flight:
			s.done = true
			for e: Enemy in enemies:
				if e.alive and e.pos.distance_to(s.land) <= SPLASH_RADIUS:
					_hit(e, s.damage, false)
			_effect(Fx.RING, s.land, Vector2.ZERO, Vector2.ZERO, 0.45, SPLASH_RADIUS, P.GLOW)
			for i: int in 7:
				var a: float = TAU * float(i) / 7.0
				_effect(Fx.STAR, s.land, Vector2(0, -0.02), Vector2(cos(a), sin(a) * 0.6 - 0.4) * 0.2, 0.6, 0.014, P.LANTERN)
		return
	if s.target != null and s.target.alive:
		s.land = s.target.pos
	var step: float = TOWER_SHOT_SPEED[s.kind] * dt
	if s.pos.distance_to(s.land) <= step:
		s.done = true
		if s.target != null and s.target.alive:
			_hit(s.target, s.damage, s.kind == Art.Tower.LOOKOUT)
			_effect(Fx.STAR, s.land, Vector2(0, -0.03), Vector2(0, -0.05), 0.35, 0.016, P.SPARKLE)
		return
	s.pos = s.pos.move_toward(s.land, step)
	if s.kind == Art.Tower.ROCKET and int(s.age * 60.0) % 3 == 0:
		_effect(Fx.STAR, s.pos, Vector2(0, -_shot_height(s)), Vector2(rng.randf_range(-0.03, 0.03), 0.03), 0.4, 0.008,
			P.SPARKLE_LILAC if rng.randf() < 0.5 else P.LANTERN)


func _shot_height(s: Shot) -> float:
	var k: float
	if s.kind == Art.Tower.BAKE:
		k = clampf(s.age / s.flight, 0.0, 1.0)
	else:
		k = clampf(1.0 - s.pos.distance_to(s.land) / s.first_dist, 0.0, 1.0)
	return lerpf(s.start_h, 0.025, k) + s.arc * sin(PI * k)


func _shot_pos(s: Shot) -> Vector2:
	if s.kind == Art.Tower.BAKE:
		# A lobbed shot keeps its start in `pos` and flies on a fixed arc.
		return s.pos.lerp(s.land, clampf(s.age / s.flight, 0.0, 1.0))
	return s.pos


func _hit(e: Enemy, damage: float, pierce: bool) -> void:
	if not e.alive:
		return
	e.hp -= damage if pierce else maxf(1.0, damage - ENEMY_ARMOR[e.kind])
	if e.hp > 0.0:
		return
	e.alive = false
	var bounty: int = ENEMY_BOUNTY[e.kind]
	gold += bounty
	var h: float = ENEMY_SIZE[e.kind] * 0.6
	for i: int in 3:
		_effect(Fx.CLOUD, e.pos, Vector2(rng.randf_range(-0.012, 0.012), -h), Vector2(rng.randf_range(-0.03, 0.03), -0.03), 0.55, ENEMY_SIZE[e.kind] * 0.45, P.SMOKE)
	for i: int in 10:
		var a: float = rng.randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a) - 0.8) * rng.randf_range(0.08, 0.2)
		_effect(Fx.STAR, e.pos, Vector2(0, -h), v, rng.randf_range(0.5, 0.9), rng.randf_range(0.008, 0.016), P.SPARKLE if i % 2 == 0 else P.SPARKLE_LILAC)
	var label: Effect = _effect(Fx.TEXT, e.pos, Vector2(0, -h * 2.0), Vector2(0, -0.06), 0.9, 0.0, P.COIN)
	label.text = "+%d" % bounty
	_sfx("puff", -8.0, 1.0, 0.06)


func _effect(kind: int, anchor: Vector2, off: Vector2, vel: Vector2, life: float, size: float, color: Color) -> Effect:
	var fx: Effect = Effect.new()
	fx.kind = kind
	fx.anchor = anchor
	fx.off = off
	fx.vel = vel
	fx.life = life
	fx.size = size
	fx.color = color
	effects.append(fx)
	return fx


func _toast(text: String) -> void:
	toast_text = text
	toast_time = 2.4


func _process(delta: float) -> void:
	anim_t += delta
	if mode == Mode.PLAY and not paused and not game_over:
		acc += delta * float(speed)
		var steps: int = 0
		while acc >= DT and steps < 12:
			_step(DT)
			acc -= DT
			steps += 1
		if steps == 12:
			acc = 0.0
	toast_time = maxf(0.0, toast_time - delta)
	route_flash = maxf(0.0, route_flash - delta * 1.5)
	_poll_music()
	world.queue_redraw()
	hud.queue_redraw()


# Input.

func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mode == Mode.PLAY:
		_tap((make_input_local(mb) as InputEventMouseButton).position)
		get_viewport().set_input_as_handled()


func _tap(p: Vector2) -> void:
	if game_over:
		_reset_game()
		return
	for b: Dictionary in buttons:
		var r: Rect2 = b["rect"]
		if r.has_point(p):
			_press(String(b["id"]))
			return
	if p.distance_to(m2s(gate_pos)) <= maxf(0.075 * ms, touch * 0.5):
		_toggle_gate()
		return
	var best: int = -1
	var best_d: float = maxf(0.07 * ms, touch * 0.5)
	for i: int in spots.size():
		var d: float = p.distance_to(m2s(spots[i]) + Vector2(0, -0.04 * ms))
		if d <= best_d:
			best = i
			best_d = d
	if best >= 0:
		_tap_spot(best)
		return
	selected_spot = -1
	selected_card = -1


func _press(id: String) -> void:
	_sfx("click", -10.0)
	match id:
		"pause":
			paused = not paused
		"speed":
			speed = speed % 3 + 1
		"start":
			if not in_wave:
				_start_wave()
		"font":
			font_mode = (font_mode + 1) % 3
			_toast("Font: %s" % _font_name())
		_:
			if id.begins_with("card"):
				var i: int = int(id.trim_prefix("card"))
				selected_card = -1 if selected_card == i else i
				selected_spot = -1


func _toggle_gate() -> void:
	if in_wave:
		_toast("Gates are locked during a wave.")
		return
	gate_closed = not gate_closed
	route_flash = 1.0
	if gate_closed:
		_sfx("gate_closed", -4.0)
		_toast("Gate closed. They take the long road.")
	else:
		_sfx("gate_opened", -4.0)
		_toast("Gate open. They take the short road.")


func _tap_spot(i: int) -> void:
	if _tower_at(i) != null:
		selected_spot = -1 if selected_spot == i else i
		selected_card = -1
		return
	if selected_card < 0:
		_toast("Pick a tower card, then tap this stone.")
		return
	var cost: int = TOWER_COST[selected_card]
	if gold < cost:
		_toast("Not enough gold yet.")
		return
	gold -= cost
	_place_tower(selected_card, i)
	_effect(Fx.RING, spots[i], Vector2.ZERO, Vector2.ZERO, 0.6, 0.09, P.LANTERN)
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		_effect(Fx.STAR, spots[i], Vector2(0, -0.05), Vector2(cos(a), sin(a) * 0.5 - 0.5) * 0.2, 0.7, 0.014, P.SPARKLE)
	_sfx("build", -5.0)
	selected_card = -1


# Painting: background (redrawn only when the layout changes).

func _paint_bg(ci: CanvasItem) -> void:
	if mode != Mode.PLAY:
		return
	art.ci = ci
	art.mono = false
	var mr: Rect2 = _map_rect()
	var horizon: float = mr.position.y + ms * 0.02
	_vgrad(ci, 0.0, horizon * 0.5, P.SKY_TOP, P.SKY_MID)
	_vgrad(ci, horizon * 0.5, horizon * 0.85, P.SKY_MID, P.SKY_LOW)
	_vgrad(ci, horizon * 0.85, horizon, P.SKY_LOW, P.SKY_GLOW)
	ci.draw_rect(Rect2(0.0, horizon, vs.x, vs.y - horizon), P.HILL_NEAR)
	var sky_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sky_rng.seed = 7
	for i: int in 70:
		var sp: Vector2 = Vector2(sky_rng.randf() * vs.x, sky_rng.randf() * horizon * 0.75)
		ci.draw_circle(sp, sky_rng.randf_range(1.2, 3.2), Color(P.STAR, sky_rng.randf_range(0.35, 0.95)), true, -1.0, true)
	var moon_c: Vector2 = Vector2(mr.position.x + mr.size.x * 0.86, lerpf(sky_top, horizon - 0.12 * ms, 0.45))
	var moon_r: float = clampf((horizon - sky_top) * 0.16, 22.0, 64.0)
	art.glow(moon_c, moon_r * 4.0, P.MOON, 1.0)
	art.moon(moon_c, moon_r)
	_hills(ci, horizon, 0.16 * ms, 0.0021, 1.3, P.HILL_FAR, true)
	_hills(ci, horizon, 0.08 * ms, 0.0034, 4.0, P.HILL_MID, false)
	_meadow(ci, mr)
	var edge_w: float = 0.1 * ms
	var road_w: float = 0.074 * ms
	for road: PackedVector2Array in roads:
		_thick(ci, _to_screen(road), edge_w, P.ROAD_EDGE)
	for road: PackedVector2Array in roads:
		_thick(ci, _to_screen(road), road_w, P.ROAD)
	var dot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	dot_rng.seed = 3
	for road: PackedVector2Array in roads:
		for i: int in range(0, road.size(), 2):
			var q: Vector2 = road[i] + Vector2(dot_rng.randf_range(-0.022, 0.022), dot_rng.randf_range(-0.022, 0.022))
			ci.draw_colored_polygon(Art.ellipse_pts(m2s(q), 0.009 * ms, 0.006 * ms, 8), P.ROAD_DOT)
	for i: int in spots.size():
		var c: Vector2 = m2s(spots[i])
		ci.draw_colored_polygon(Art.ellipse_pts(c + Vector2(0, 0.004 * ms), 0.064 * ms, 0.032 * ms, 24), P.PAD_EDGE)
		ci.draw_colored_polygon(Art.ellipse_pts(c, 0.058 * ms, 0.027 * ms, 24), P.PAD)
		ci.draw_arc(c, 0.04 * ms, 0.0, TAU, 24, Color(P.PAD_EDGE, 0.5), 2.0, true)
	# Decor, drawn back to front.
	var decor: Array[Vector3] = trees.duplicate()
	decor.sort_custom(func(a: Vector3, b: Vector3) -> bool: return m2s(Vector2(a.x, a.y)).y < m2s(Vector2(b.x, b.y)).y)
	for tr: Vector3 in decor:
		art.tree(m2s(Vector2(tr.x, tr.y)), 0.1 * ms, int(tr.z))
	art.cottage(m2s(Vector2(0.13, 1.33)), 0.11 * ms, P.ROOF_SLATE, false)
	art.cottage(m2s(Vector2(0.87, 1.33)), 0.11 * ms, P.ROOF_PLUM, true)
	art.hearth_hall(m2s(Vector2(0.5, 1.34)), 0.3 * ms)


func _vgrad(ci: CanvasItem, y0: float, y1: float, c0: Color, c1: Color) -> void:
	if y1 <= y0:
		return
	ci.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(vs.x, y0), Vector2(vs.x, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _hills(ci: CanvasItem, base: float, height: float, freq: float, seed_phase: float, col: Color, lights: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(0, base + 4.0)])
	var x: float = 0.0
	while x <= vs.x + 24.0:
		var h: float = height * (0.55 + 0.3 * sin(x * freq + seed_phase) + 0.15 * sin(x * freq * 2.7 + seed_phase * 2.0))
		pts.append(Vector2(x, base - h))
		x += 24.0
	pts.append(Vector2(vs.x + 24.0, base + 4.0))
	ci.draw_colored_polygon(pts, col)
	if lights:
		for i: int in 7:
			var lx: float = vs.x * (0.08 + 0.13 * float(i))
			var lh: float = height * (0.55 + 0.3 * sin(lx * freq + seed_phase) + 0.15 * sin(lx * freq * 2.7 + seed_phase * 2.0))
			var lp: Vector2 = Vector2(lx, base - lh * 0.55)
			ci.draw_circle(lp, 9.0, Color(P.GLOW, 0.18), true, -1.0, true)
			ci.draw_circle(lp, 3.0, P.LANTERN, true, -1.0, true)


func _meadow(ci: CanvasItem, mr: Rect2) -> void:
	var r: Rect2 = mr.grow(0.03 * ms)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 18
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side: int in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var outward: Vector2 = Vector2((b - a).y, -(b - a).x).normalized()
		for k: int in steps:
			var t: float = float(k) / float(steps)
			var wob: float = sin(float(side * steps + k) * 1.7) * 0.012 * ms
			if side == 0:
				wob += sin(t * PI) * 0.03 * ms
			pts.append(a.lerp(b, t) + outward * wob)
	ci.draw_colored_polygon(pts, P.MEADOW)
	var patch_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	patch_rng.seed = 5
	for i: int in 14:
		var c: Vector2 = m2s(Vector2(patch_rng.randf(), patch_rng.randf() * MAP_ALONG))
		ci.draw_colored_polygon(Art.ellipse_pts(c, patch_rng.randf_range(0.08, 0.16) * ms, patch_rng.randf_range(0.04, 0.08) * ms, 20), Color(P.MEADOW_LIGHT, 0.55))
	for p: Vector2 in tufts:
		var c: Vector2 = m2s(p)
		var s: float = 0.012 * ms
		ci.draw_line(c, c + Vector2(-s * 0.6, -s), P.MEADOW_DARK, 2.5, true)
		ci.draw_line(c, c + Vector2(0, -s * 1.3), P.MEADOW_DARK, 2.5, true)
		ci.draw_line(c, c + Vector2(s * 0.6, -s), P.MEADOW_DARK, 2.5, true)
	var petals: Array[Color] = [P.PLASTER, P.SPARKLE_LILAC, P.HONEY, P.HEART]
	for i: int in flowers.size():
		var c: Vector2 = m2s(flowers[i])
		ci.draw_circle(c, 0.0065 * ms, petals[i % petals.size()], true, -1.0, true)
		ci.draw_circle(c, 0.0025 * ms, P.LANTERN, true, -1.0, true)


func _to_screen(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(m2s(p))
	return out


func _thick(ci: CanvasItem, pts: PackedVector2Array, width: float, col: Color) -> void:
	ci.draw_polyline(pts, col, width, true)
	for p: Vector2 in pts:
		ci.draw_circle(p, width * 0.5, col, true, -1.0, true)


# Painting: the living world (every frame).

func _paint_world(ci: CanvasItem) -> void:
	if mode != Mode.PLAY:
		return
	art.ci = ci
	art.mono = false
	art.t = anim_t
	_paint_route(ci)
	_paint_gate()
	if selected_card >= 0:
		for i: int in spots.size():
			if _tower_at(i) == null:
				var c: Vector2 = m2s(spots[i])
				var pulse: float = 0.5 + 0.5 * sin(anim_t * 5.0)
				ci.draw_arc(c, 0.07 * ms, 0.0, TAU, 32, P.INK_LINE, 9.0, true)
				ci.draw_arc(c, 0.07 * ms, 0.0, TAU, 32, Color(P.HONEY, 0.6 + 0.4 * pulse), 5.0, true)
	if selected_spot >= 0:
		var stw: Tower = _tower_at(selected_spot)
		if stw != null and TOWER_RANGE[stw.kind] > 0.0:
			_range_ring(ci, m2s(spots[selected_spot]), TOWER_RANGE[stw.kind] * ms)
	for tw: Tower in towers:
		if tw.kind == Art.Tower.LANTERN:
			for other: Tower in towers:
				if other != tw and spots[tw.spot].distance_to(spots[other.spot]) <= TOWER_RANGE[Art.Tower.LANTERN]:
					var a: Vector2 = m2s(spots[tw.spot]) + Vector2(0.012, -0.1) * ms
					var b: Vector2 = m2s(spots[other.spot]) + Vector2(0, -0.05 * ms)
					var n: int = 9
					for k: int in n:
						var f: float = fmod(float(k) / float(n) + anim_t * 0.25, 1.0)
						ci.draw_circle(a.lerp(b, f), 0.006 * ms, Color(P.LANTERN, 0.75 * sin(f * PI)), true, -1.0, true)
	# Towers, creatures and the thicket, sorted by screen height.
	var items: Array = []
	for tw: Tower in towers:
		items.append([m2s(spots[tw.spot]).y, tw])
	for e: Enemy in enemies:
		items.append([m2s(e.pos).y, e])
	var thicket_at: Vector2 = m2s(Vector2(0.5, 0.06))
	items.append([thicket_at.y, null])
	items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for item: Array in items:
		var obj: Object = item[1]
		if obj == null:
			art.thicket(thicket_at, 0.44 * ms, anim_t)
		elif obj is Tower:
			_paint_tower(ci, obj as Tower)
		else:
			var e: Enemy = obj as Enemy
			art.t = sim_t
			art.creature(e.kind, m2s(e.pos), ENEMY_SIZE[e.kind] * ms, e.face_left, e.phase, e.slow_time > 0.0)
			art.t = anim_t
	for e: Enemy in enemies:
		if e.hp < e.max_hp:
			var c: Vector2 = m2s(e.pos) + Vector2(0, -ENEMY_SIZE[e.kind] * 1.45 * ms)
			var w: float = 0.05 * ms
			var r: Rect2 = Rect2(c.x - w * 0.5, c.y, w, 0.009 * ms)
			ci.draw_rect(r.grow(2.0), P.HP_BACK)
			ci.draw_rect(Rect2(r.position, Vector2(w * clampf(e.hp / e.max_hp, 0.0, 1.0), r.size.y)), P.HP_FILL)
	for s: Shot in shots:
		_paint_shot(ci, s)
	for fx: Effect in effects:
		_paint_effect(ci, fx)
	for i: int in fireflies.size():
		var f: Vector2 = fireflies[i]
		var drift: Vector2 = Vector2(sin(anim_t * 0.4 + float(i)) * 0.03, cos(anim_t * 0.33 + float(i) * 1.7) * 0.02)
		var c: Vector2 = m2s(f + drift)
		var tw_a: float = 0.5 + 0.5 * sin(anim_t * 2.2 + float(i) * 2.3)
		ci.draw_circle(c, 0.012 * ms, Color(P.LANTERN, 0.15 * tw_a), true, -1.0, true)
		ci.draw_circle(c, 0.0035 * ms, Color(P.LANTERN_CORE, 0.4 + 0.6 * tw_a), true, -1.0, true)


func _paint_route(ci: CanvasItem) -> void:
	var r: int = 1 if gate_closed else 0
	var total: float = _route_length(r)
	var alpha: float = 0.4 if in_wave else 1.0
	alpha = minf(1.0, alpha + route_flash)
	var period: float = 0.06
	var dash: float = 0.028
	var d: float = 0.09 + fmod(anim_t * 0.1, period)
	var casing: float = 0.017 * ms + route_flash * 6.0
	var core: float = 0.008 * ms + route_flash * 4.0
	while d + dash < total - 0.08:
		var a: Vector2 = m2s(_point_at(r, d))
		var b: Vector2 = m2s(_point_at(r, d + dash))
		ci.draw_line(a, b, Color(P.INK_LINE, 0.8 * alpha), casing, true)
		ci.draw_line(a, b, Color(P.ROUTE, alpha), core, true)
		d += period
	# Chevrons show which way the creatures walk.
	var c: float = 0.3
	while c < total - 0.1:
		var p: Vector2 = m2s(_point_at(r, c))
		var dir: Vector2 = (m2s(_point_at(r, c + 0.01)) - p).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var s: float = 0.022 * ms
		var tip: Vector2 = p + dir * s
		var pts: PackedVector2Array = PackedVector2Array([p - dir * s * 0.2 + side * s, tip, p - dir * s * 0.2 - side * s])
		ci.draw_polyline(pts, Color(P.INK_LINE, 0.8 * alpha), casing, true)
		ci.draw_polyline(pts, Color(P.ROUTE, alpha), core, true)
		c += 0.32


func _paint_gate() -> void:
	var c: Vector2 = m2s(gate_pos)
	var along: Vector2 = m2s_dir(gate_dir).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	if across.x < 0.0:
		across = -across
	if gate_closed:
		# A bar on the ground across the road, then the gate itself.
		world.draw_line(c - across * 0.042 * ms, c + across * 0.042 * ms, P.INK_LINE, 0.03 * ms, true)
		world.draw_line(c - across * 0.04 * ms, c + across * 0.04 * ms, P.WOOD, 0.018 * ms, true)
	# On a road that runs across the screen the gate faces the viewer.
	if absf(across.x) < 0.6:
		across = Vector2.RIGHT
	var pulse: float = 0.5 + 0.5 * sin(anim_t * 4.0)
	if not gate_closed and not in_wave:
		art.glow(c, 0.13 * ms, P.ROUTE, 0.8 + 0.6 * pulse)
	art.gate(c, across, 0.06 * ms, 0.075 * ms, gate_closed, pulse if not in_wave else 0.0)


func _paint_tower(ci: CanvasItem, tw: Tower) -> void:
	var base: Vector2 = m2s(spots[tw.spot])
	var size: float = TOWER_SIZE * ms
	var aim: float = -PI / 2.0
	if tw.has_aim:
		aim = (m2s(tw.aim_at) - (base + Vector2(0, -1.6 * size))).angle()
	art.tower(tw.kind, base, size, aim, tw.flash)
	if tw.boosted:
		var top: Vector2 = base + Vector2(-0.5 * size, -0.3 * size)
		var s: float = 0.16 * size
		for k: int in 2:
			var y: float = top.y - float(k) * s * 0.8 + sin(anim_t * 3.0) * 2.0
			var pts: PackedVector2Array = PackedVector2Array([Vector2(top.x - s, y + s * 0.5), Vector2(top.x, y - s * 0.4), Vector2(top.x + s, y + s * 0.5)])
			ci.draw_polyline(pts, P.INK_LINE, 9.0, true)
			ci.draw_polyline(pts, P.LANTERN, 4.5, true)


func _paint_shot(ci: CanvasItem, s: Shot) -> void:
	var map_pos: Vector2 = _shot_pos(s)
	var p: Vector2 = m2s(map_pos) + Vector2(0, -_shot_height(s) * ms)
	match s.kind:
		Art.Tower.WATCH:
			ci.draw_circle(p, 0.009 * ms, P.INK_LINE, true, -1.0, true)
			ci.draw_circle(p, 0.006 * ms, P.SPARKLE, true, -1.0, true)
		Art.Tower.BAKE:
			art.glow(p, 0.05 * ms, P.GLOW, 1.4)
			ci.draw_circle(p, 0.016 * ms, P.INK_LINE, true, -1.0, true)
			ci.draw_circle(p, 0.012 * ms, P.LANTERN, true, -1.0, true)
			ci.draw_circle(p + Vector2(-0.003, -0.003) * ms, 0.005 * ms, P.LANTERN_CORE, true, -1.0, true)
		Art.Tower.LOOKOUT:
			var dir: Vector2 = m2s_dir((s.land - s.pos).normalized())
			ci.draw_line(p - dir * 0.05 * ms, p, P.INK_LINE, 0.011 * ms, true)
			ci.draw_line(p - dir * 0.05 * ms, p, P.LANTERN_CORE, 0.005 * ms, true)
		Art.Tower.ROCKET:
			art.glow(p, 0.03 * ms, P.SPARKLE_LILAC, 1.2)
			ci.draw_circle(p, 0.01 * ms, P.INK_LINE, true, -1.0, true)
			ci.draw_circle(p, 0.0065 * ms, P.HONEY, true, -1.0, true)


func _paint_effect(ci: CanvasItem, fx: Effect) -> void:
	var k: float = clampf(fx.age / fx.life, 0.0, 1.0)
	var c: Vector2 = m2s(fx.anchor) + fx.off * ms
	match fx.kind:
		Fx.STAR:
			var r: float = fx.size * ms * (1.0 - k * 0.6)
			art.star(c, r, Color(fx.color, 1.0 - k * k))
		Fx.CLOUD:
			var r: float = fx.size * ms * (0.6 + k * 0.9)
			ci.draw_circle(c, r, Color(fx.color, 0.55 * (1.0 - k)), true, -1.0, true)
		Fx.TEXT:
			_outlined(ci, c, fx.text, maxi(14, int(0.036 * ms)), Color(fx.color, 1.0 - k * k))
		Fx.RING:
			var r: float = fx.size * ms * (0.3 + 0.7 * sqrt(k))
			ci.draw_arc(m2s(fx.anchor), r, 0.0, TAU, 40, Color(fx.color, 0.7 * (1.0 - k)), 0.012 * ms * (1.0 - k) + 2.0, true)


func _range_ring(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color(P.LANTERN, 0.1), true, -1.0, true)
	ci.draw_arc(c, r, 0.0, TAU, 72, Color(P.INK_LINE, 0.7), 9.0, true)
	ci.draw_arc(c, r, 0.0, TAU, 72, P.LANTERN, 4.5, true)


# Painting: the HUD.

func _paint_hud(ci: CanvasItem) -> void:
	art.ci = ci
	art.mono = false
	art.t = anim_t
	if mode == Mode.SHEET:
		Showcase.draw_sheet(ci, art, fb(), fr(), vs)
		return
	if mode == Mode.ICON:
		Showcase.draw_icon(ci, art, vs)
		return
	if landscape:
		var col: Rect2 = Rect2(stats_rect.position.x - 12.0, stats_rect.position.y - 12.0, stats_rect.size.x + 24.0, _button_rect("start").end.y - stats_rect.position.y + 24.0)
		_panel(ci, col, Color(P.PANEL, 0.55), Color(P.PANEL_EDGE, 0.6), 34.0, 2.0)
	_paint_stats(ci)
	_panel(ci, hint_rect, P.PANEL, P.PANEL_EDGE, 24.0, 3.0)
	_wrapped(ci, hint_rect.grow(-16.0), _hint(), 40, P.TEXT_LIGHT, fr())
	for b: Dictionary in buttons:
		if _caption and b["id"] == "font":
			continue
		_paint_button(ci, String(b["id"]), b["rect"])
	if selected_spot >= 0:
		_paint_tower_card(ci)
	if paused or game_over:
		var mr: Rect2 = map_region
		ci.draw_rect(mr, Color(P.PANEL, 0.45))
		var title: String = "The village is asleep" if game_over else "Paused"
		var sub: String = "Tap anywhere to start again." if game_over else "You can still build and look around."
		var card_w: float = minf(mr.size.x - 80.0, 900.0)
		var card: Rect2 = Rect2(mr.get_center().x - card_w * 0.5, mr.get_center().y - 150.0, card_w, 260.0)
		_panel(ci, card, P.PANEL, P.HONEY, 32.0, 3.0)
		_text(ci, Rect2(card.position.x + 30.0, card.position.y + 20.0, card.size.x - 60.0, 130.0), title, 90, P.TEXT_LIGHT, fb())
		_text(ci, Rect2(card.position.x + 30.0, card.position.y + 160.0, card.size.x - 60.0, 70.0), sub, 40, P.TEXT_LIGHT, fr())
	if toast_time > 0.0 and not toast_text.is_empty():
		var font: Font = fb()
		var w: float = minf(map_region.size.x - 60.0, font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 70.0)
		var r: Rect2 = Rect2(map_region.get_center().x - w * 0.5, map_region.position.y + 30.0, w, 92.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var fade: float = clampf(toast_time * 3.0, 0.0, 1.0)
		_panel(ci, r, Color(P.PANEL, fade), Color(P.HONEY, fade), 46.0, 3.0)
		_text(ci, r.grow(-20.0), toast_text, 38, Color(P.TEXT_LIGHT, fade), font)
	if _caption:
		_paint_caption(ci)


func _hint() -> String:
	if game_over:
		return "The night creatures got through. Tap anywhere to start again."
	if selected_card >= 0:
		return "Tap an empty stone to build the %s (%d gold)." % [Art.TOWER_NAMES[selected_card], TOWER_COST[selected_card]]
	if in_wave:
		var label: String = _demo_label if not _demo_label.is_empty() else WAVE_NAMES[(wave - 1) % 4]
		return "Wave %d: %s. Gates stay put until the wave ends." % [wave, label]
	if not gate_closed:
		return "Tap the glowing ring on the short road to close it with a gate."
	return "The gate sends them the long way, past more towers. Tap Start wave."


func _paint_stats(ci: CanvasItem) -> void:
	_panel(ci, stats_rect, P.PANEL, P.PANEL_EDGE, 28.0, 3.0)
	var cell_w: float = stats_rect.size.x / 3.0
	var h: float = stats_rect.size.y
	var values: PackedStringArray = [str(lives), str(gold), "Wave %d" % maxi(1, wave)]
	for i: int in 3:
		var cell: Rect2 = Rect2(stats_rect.position.x + cell_w * float(i), stats_rect.position.y, cell_w, h)
		var icon_c: Vector2 = Vector2(cell.position.x + h * 0.36, cell.get_center().y)
		var r: float = h * 0.17
		match i:
			0:
				art.heart(icon_c, r, P.HEART)
			1:
				art.coin(icon_c, r)
			2:
				art.moon(icon_c, r)
		var text_r: Rect2 = Rect2(icon_c.x + r + 12.0, cell.position.y, cell.end.x - icon_c.x - r - 22.0, h)
		_text(ci, text_r, values[i], 50, P.TEXT_LIGHT, fb(), HORIZONTAL_ALIGNMENT_LEFT)


func _paint_button(ci: CanvasItem, id: String, r: Rect2) -> void:
	if id.begins_with("card"):
		_paint_card(ci, int(id.trim_prefix("card")), r)
		return
	match id:
		"start":
			if in_wave:
				_panel(ci, r, P.PANEL_RAISED, P.PANEL_EDGE, 30.0, 3.0)
				_text(ci, r.grow(-20.0), "Wave %d underway" % wave, 46, P.TEXT_LIGHT, fb())
			else:
				_panel(ci, r, P.HONEY, P.INK_LINE, 30.0, 4.0)
				_text(ci, r.grow(-20.0), "Start wave %d" % (wave + 1), 52, P.TEXT_DARK, fb())
		"pause":
			_panel(ci, r, P.PANEL_RAISED, P.PANEL_EDGE, 30.0, 3.0)
			var c: Vector2 = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.4)
			var s: float = r.size.y * 0.16
			if paused:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s), c + Vector2(s * 1.1, 0), c + Vector2(-s * 0.8, s)]), P.TEXT_LIGHT)
			else:
				ci.draw_rect(Rect2(c.x - s * 0.9, c.y - s, s * 0.6, s * 2.0), P.TEXT_LIGHT)
				ci.draw_rect(Rect2(c.x + s * 0.3, c.y - s, s * 0.6, s * 2.0), P.TEXT_LIGHT)
			_text(ci, Rect2(r.position.x + 6.0, r.position.y + r.size.y * 0.64, r.size.x - 12.0, r.size.y * 0.3), "Play" if paused else "Pause", 32, P.TEXT_LIGHT, fr())
		"speed":
			_panel(ci, r, P.PANEL_RAISED, P.PANEL_EDGE, 30.0, 3.0)
			_text(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.12, r.size.x, r.size.y * 0.5), "%dx" % speed, 56, P.TEXT_LIGHT, fb())
			_text(ci, Rect2(r.position.x + 6.0, r.position.y + r.size.y * 0.64, r.size.x - 12.0, r.size.y * 0.3), "Speed", 32, P.TEXT_LIGHT, fr())
		"font":
			_panel(ci, r, P.PANEL_RAISED, P.PANEL_EDGE, 30.0, 3.0)
			_text(ci, Rect2(r.position.x + 10.0, r.position.y + r.size.y * 0.12, r.size.x - 20.0, r.size.y * 0.5), _font_name(), 48, P.TEXT_LIGHT, fb())
			_text(ci, Rect2(r.position.x + 10.0, r.position.y + r.size.y * 0.64, r.size.x - 20.0, r.size.y * 0.3), "Font (slice only)", 28, P.TEXT_LIGHT, fr())


func _paint_card(ci: CanvasItem, kind: int, r: Rect2) -> void:
	var afford: bool = gold >= TOWER_COST[kind]
	var selected: bool = selected_card == kind
	var rr: Rect2 = r
	if selected:
		rr.position.y -= 10.0
	_panel(ci, rr, P.CARD if afford else P.CARD_DIM, P.HONEY if selected else P.INK_LINE, 22.0, 7.0 if selected else 3.0)
	var icon_h: float = rr.size.y * 0.56
	art.tower(kind, Vector2(rr.get_center().x, rr.position.y + icon_h + 6.0), icon_h / 2.25)
	_text(ci, Rect2(rr.position.x + 6.0, rr.position.y + icon_h + 10.0, rr.size.x - 12.0, rr.size.y * 0.2), Art.TOWER_SHORT[kind], 36, P.TEXT_DARK, fb())
	var cost_r: Rect2 = Rect2(rr.position.x + 6.0, rr.position.y + rr.size.y * 0.78, rr.size.x - 12.0, rr.size.y * 0.18)
	var cost_s: String = str(TOWER_COST[kind])
	var tw: float = fr().get_string_size(cost_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var coin_r: float = cost_r.size.y * 0.3
	var cx: float = cost_r.get_center().x - (tw + coin_r * 2.0 + 8.0) * 0.5
	art.coin(Vector2(cx + coin_r, cost_r.get_center().y), coin_r)
	_text(ci, Rect2(cx + coin_r * 2.0 + 8.0, cost_r.position.y, tw + 4.0, cost_r.size.y), cost_s, 32, P.TEXT_MUTED, fr(), HORIZONTAL_ALIGNMENT_LEFT)


func _paint_tower_card(ci: CanvasItem) -> void:
	var tw: Tower = _tower_at(selected_spot)
	if tw == null:
		return
	var base: Vector2 = m2s(spots[selected_spot])
	var title: String = Art.TOWER_NAMES[tw.kind]
	var role: String = Art.TOWER_ROLES[tw.kind]
	var w: float = maxf(fb().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, fr().get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x) + 60.0
	var h: float = 120.0
	var top: float = base.y - TOWER_SIZE * ms * 2.3 - h
	var x: float = clampf(base.x - w * 0.5, 12.0, vs.x - w - 12.0)
	if top < map_region.position.y:
		top = base.y + 0.06 * ms
	var r: Rect2 = Rect2(x, top, w, h)
	_panel(ci, r, P.PANEL, P.HONEY, 24.0, 3.0)
	_text(ci, Rect2(r.position.x + 20.0, r.position.y + 10.0, r.size.x - 40.0, 56.0), title, 40, P.TEXT_LIGHT, fb())
	_text(ci, Rect2(r.position.x + 20.0, r.position.y + 62.0, r.size.x - 40.0, 44.0), role, 34, P.TEXT_LIGHT, fr())


func _paint_caption(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, vs.x, CAPTION_H + MARGIN * 0.5), P.SKY_TOP)
	_text(ci, Rect2(40.0, 40.0, vs.x - 80.0, 120.0), "Close a road.", 100, P.TEXT_LIGHT, fb())
	_text(ci, Rect2(40.0, 150.0, vs.x - 80.0, 120.0), "Steer the night.", 100, P.LANTERN, fb())


# Screenshots for docs/art.

func _demo() -> void:
	if _build_moment:
		selected_card = Art.Tower.WATCH
		for i: int in 90:
			_step(DT)
		anim_t = 0.6
		return
	gate_closed = true
	_demo_label = "all four creatures"
	wave = 1
	in_wave = true
	wave_clock = 0.0
	hp_mult = 3.0
	spawn_queue = [
		[0.0, Art.Creature.ARMORED], [1.2, Art.Creature.BASIC], [2.6, Art.Creature.BASIC], [3.6, Art.Creature.FAST],
		[4.4, Art.Creature.ARMORED], [5.2, Art.Creature.SWARM], [5.4, Art.Creature.SWARM], [5.6, Art.Creature.SWARM],
		[5.8, Art.Creature.SWARM], [6.0, Art.Creature.SWARM], [7.0, Art.Creature.BASIC], [8.2, Art.Creature.FAST],
		[9.0, Art.Creature.BASIC], [10.0, Art.Creature.SWARM], [10.2, Art.Creature.SWARM], [10.4, Art.Creature.SWARM]]
	for i: int in int(11.5 / DT):
		_step(DT)
	selected_spot = 3
	anim_t = sim_t


func _capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	print("Saved %s (%dx%d): %s" % [path, img.get_width(), img.get_height(), error_string(err)])
	if mode == Mode.ICON and err == OK:
		var small: Image = img.duplicate() as Image
		small.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		var small_path: String = path.get_basename() + "_48.png"
		err = small.save_png(small_path)
		print("Saved %s (48x48): %s" % [small_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)


func _capture_showcase() -> void:
	bg.visible = false
	world.visible = false
	_capture(_shot_path)
