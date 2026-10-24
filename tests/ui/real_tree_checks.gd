# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Checks that need a running scene tree: real layout at both Fold5 sizes, touch
## sizes, and real touches pushed through the GUI. The test runner builds its
## tests before the tree runs, so tests/ui/test_real_tree.gd starts this script
## in a second Godot process and reads what it prints.
##
##     godot --headless --path . --script res://tests/ui/real_tree_checks.gd
##
## Every problem prints a line starting with "FAIL". The exit code is 0 when
## nothing failed. A watchdog ends the run if it ever hangs.

const COVER: Vector2 = Vector2(1080.0, 2767.0)
const INNER: Vector2 = Vector2(1998.0, 2400.0)
const COVER_SAFE: Rect2 = Rect2(0.0, 96.0, 1080.0, 2500.0)
const INNER_SAFE: Rect2 = Rect2(0.0, 0.0, 1998.0, 2250.0)
const WATCHDOG_SECONDS: float = 90.0


## Stands in for the phone: remembers every address handed to it.
class Recorder extends RefCounted:
	var urls: Array[String] = []

	func record(url: String) -> void:
		urls.append(url)


var failures: int = 0
var checks: int = 0
var recorder: Recorder = Recorder.new()


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


func _frames(count: int = 3) -> void:
	for i: int in count:
		await process_frame


func _viewport(size: Vector2) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(size)
	root.add_child(vp)
	return vp


func _hosted(vp: SubViewport, screen: Control, size: Vector2, safe: Rect2) -> void:
	var holder: Control = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(holder)
	holder.add_child(screen)
	screen.call("apply_layout", size, safe)
	await _frames()


func _run() -> void:
	Links.opener = recorder.record
	await _touch_sizes()
	await _front_door()
	await _taps()
	await _about_first_screenful()
	await _battle_panels()
	await _app()
	Links.opener = Callable()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


# Touch sizes.

const SCREEN_NAMES: PackedStringArray = [
	"front door", "mode screen", "mode screen open", "info", "about", "license viewer",
	"settings", "pause", "confirm",
]


func _make(label: String) -> Control:
	match label:
		"front door":
			return FrontDoor.new()
		"mode screen":
			var locked: ModeScreen = ModeScreen.new()
			locked.set_continue("Continue", "Pick up where you left off.")
			locked.set_runs(false, 0, 12)
			return locked
		"mode screen open":
			var open: ModeScreen = ModeScreen.new()
			open.set_runs(true, 14, 12)
			return open
		"info":
			return InfoScreen.new()
		"about":
			return AboutScreen.new()
		"license viewer":
			return LicenseViewer.new("Test", LicenseText.build(LicenseText.FONT))
		"settings":
			return SettingsPanel.new(true)
		"pause":
			return PausePanel.new()
	return ConfirmDialog.new("Sure?", "This cannot be undone.", "Yes")


func _touch_sizes() -> void:
	var sizes: Array[Vector2] = [COVER, INNER]
	var safes: Array[Rect2] = [COVER_SAFE, INNER_SAFE]
	for label: String in SCREEN_NAMES:
		for i: int in sizes.size():
			var vp: SubViewport = _viewport(sizes[i])
			var screen: Control = _make(label)
			await _hosted(vp, screen, sizes[i], safes[i])
			var found: int = 0
			for node: Node in screen.find_children("*", "BaseButton", true, false):
				var button: BaseButton = node as BaseButton
				if not button.is_visible_in_tree():
					continue
				found += 1
				var where: String = "%s at %s: button '%s'" % [label, sizes[i], str((button as Button).text)]
				check(button.size.x >= Layout.MIN_TOUCH - 0.5, "%s is too narrow (%s)" % [where, button.size.x])
				check(button.size.y >= Layout.MIN_TOUCH - 0.5, "%s is too short (%s)" % [where, button.size.y])
				var rect: Rect2 = button.get_global_rect()
				check(rect.position.x >= -0.5 and rect.end.x <= sizes[i].x + 0.5, "%s runs off the screen sideways %s" % [where, rect])
			check(found > 0, "%s at %s has buttons" % [label, sizes[i]])
			vp.queue_free()


func _front_door() -> void:
	var vp: SubViewport = _viewport(COVER)
	var door: FrontDoor = FrontDoor.new()
	await _hosted(vp, door, COVER, COVER_SAFE)
	for button: TapButton in [door.play_button, door.info_button, door.about_button]:
		check(button.get_global_rect().get_center().y > COVER.y * 0.5, "a main button is too high for one thumb in portrait")
	check(door.coffee_button.get_global_rect().position.y > door.about_button.get_global_rect().end.y, "coffee is below the main buttons")
	check(door.settings_button.get_global_rect().end.x > COVER.x - 100.0, "the gear is at the top right")
	check(door.settings_button.get_global_rect().position.y < 400.0, "the gear is at the top")
	check(not door.landscape, "the cover screen is portrait")
	vp.queue_free()
	var vp2: SubViewport = _viewport(INNER)
	var door2: FrontDoor = FrontDoor.new()
	await _hosted(vp2, door2, INNER, INNER_SAFE)
	check(door2.landscape, "the inner screen is landscape")
	check(door2.art.get_global_rect().end.x <= door2.play_button.get_global_rect().position.x, "landscape: the picture is left of the buttons")
	vp2.queue_free()


# Real touches.

func _touch(vp: SubViewport, at: Vector2, travel: Vector2 = Vector2.ZERO) -> void:
	_press(vp, at, true)
	for i: int in 4:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = at + travel * float(i + 1) / 4.0
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(motion)
	_press(vp, at + travel, false)


func _press(vp: SubViewport, at: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	vp.push_input(event)


func _coffee_in(vp: SubViewport) -> CoffeeButton:
	var button: CoffeeButton = CoffeeButton.new()
	vp.add_child(button)
	button.position = Vector2(100, 100)
	button.size = Vector2(700, 200)
	return button


func _taps() -> void:
	var vp: SubViewport = _viewport(Vector2(1080, 1000))
	var button: CoffeeButton = _coffee_in(vp)
	await _frames()
	var inside: Vector2 = Vector2(150, 150)
	recorder.urls.clear()
	_touch(vp, inside)
	check(recorder.urls == ([Links.COFFEE_URL] as Array[String]), "one clean tap hands the coffee address over exactly once, got %s" % [recorder.urls])
	recorder.urls.clear()
	_touch(vp, inside, Vector2(TapButton.DEADZONE * 0.5, 0.0))
	check(recorder.urls.size() == 1, "a small wobble still counts as a tap")
	recorder.urls.clear()
	_touch(vp, inside, Vector2(TapButton.DEADZONE * 3.0, 0.0))
	check(recorder.urls.size() == 0, "a drag that ends on the button is not a tap")
	_touch(vp, inside, Vector2(0.0, 600.0))
	check(recorder.urls.size() == 0, "a press that ends off the button is not a tap")
	# Out and back.
	_press(vp, inside, true)
	for point: Vector2 in [Vector2(300, 150), inside]:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(motion)
	_press(vp, inside, false)
	check(recorder.urls.size() == 0, "a drag that goes out and comes back is not a tap")
	recorder.urls.clear()
	_touch(vp, inside)
	_touch(vp, inside)
	check(recorder.urls.size() == 2, "two taps hand over twice")
	vp.queue_free()
	# A scroll between down and up.
	var vp2: SubViewport = _viewport(Vector2(1080, 1000))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size = Vector2(900, 500)
	vp2.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	var head: Control = Control.new()
	head.custom_minimum_size = Vector2(800, 100)
	column.add_child(head)
	var in_scroll: CoffeeButton = CoffeeButton.new()
	column.add_child(in_scroll)
	var tail: Control = Control.new()
	tail.custom_minimum_size = Vector2(800, 1500)
	column.add_child(tail)
	scroll.add_child(column)
	await _frames()
	var at: Vector2 = in_scroll.get_global_rect().get_center()
	recorder.urls.clear()
	_press(vp2, at, true)
	scroll.scroll_vertical = 40
	await _frames()
	_press(vp2, at, false)
	check(recorder.urls.size() == 0, "a scroll between down and up is not a tap")
	check(scroll.scroll_vertical == 40, "the test did scroll")
	_touch(vp2, in_scroll.get_global_rect().get_center())
	check(recorder.urls.size() == 1, "a clean tap inside a scroll container still works")
	vp2.queue_free()


# About.

func _about_first_screenful() -> void:
	for pair: Array in [[COVER, COVER_SAFE], [INNER, INNER_SAFE]]:
		var size: Vector2 = pair[0]
		var vp: SubViewport = _viewport(size)
		var screen: AboutScreen = AboutScreen.new()
		await _hosted(vp, screen, size, pair[1])
		for node: Control in [screen.wordmark, screen.version_label, screen.made_by_label, screen.copyright_label, screen.source_button]:
			check(node != null, "brand block part is missing at %s" % size)
			if node != null:
				check(node.get_global_rect().end.y <= size.y, "a brand block part is below the first screenful at %s" % size)
		check(screen.coffee_button.get_global_rect().end.y < screen.license_buttons[LicenseText.FORKLINE].get_global_rect().position.y, "Supporting comes before the license rows")
		recorder.urls.clear()
		_touch(vp, screen.source_button.get_global_rect().get_center())
		check(recorder.urls == ([Links.SOURCE_URL] as Array[String]), "the source link hands the source address over once, got %s" % [recorder.urls])
		vp.queue_free()


# The battle panels: real Battle objects, at both Fold5 sizes.

const BattleFixtures: GDScript = preload("res://tests/ui/battle_fixtures.gd")


## A themed host with a column the width a layout gives the panels: the whole safe
## width in portrait, a side panel of 760 in landscape.
func _panel_host(size: Vector2, wide: bool) -> Array:
	var vp: SubViewport = _viewport(size)
	var holder: Control = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.theme = UiTheme.build()
	vp.add_child(holder)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	var width: float = 1008.0 if wide else 760.0
	column.position = Vector2(36.0 if wide else size.x - 36.0 - width, 132.0 if wide else 36.0)
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size = Vector2(width, 100.0)
	holder.add_child(column)
	return [vp, column, width]


func _battle_panels() -> void:
	for pair: Array in [[COVER, true], [INNER, false]]:
		var size: Vector2 = pair[0]
		var wide: bool = pair[1]
		for state: String in ["hud", "build", "build six", "tower 1", "paths", "path picked", "tier 3", "creature", "preview", "strip", "preview boss", "strip many", "hud wave", "boss creature"]:
			var host: Array = _panel_host(size, wide)
			var vp: SubViewport = host[0]
			var column: VBoxContainer = host[1]
			var width: float = host[2]
			var b: Battle = BattleFixtures.battle(&"r1_l6")
			b.gold = 900
			var cell: Vector2i = b.level.spots[0]
			var hud: BattleHud = BattleHud.new()
			hud.set_wide(wide)
			hud.refresh(b)
			var panel: BattlePanel = null
			match state:
				"build", "build six":
					if state == "build six":
						b = BattleFixtures.all_towers_battle(&"r1_l6")
						b.gold = 900
					var build: BuildPanel = BuildPanel.new()
					build.setup(b)
					build.set_wide(wide)
					build.show_spot(cell)
					panel = build
				"tower 1", "paths", "path picked", "tier 3":
					b.place_tower(cell, &"pumpkin_catapult")
					if state != "tower 1":
						b.upgrade_tower(cell)
					if state == "tier 3":
						b.upgrade_tower(cell, 1)
					var tower: TowerPanel = TowerPanel.new()
					tower.setup(b)
					tower.set_wide(wide)
					tower.show_tower(cell)
					if state == "path picked":
						tower.pick_path(0)
					panel = tower
				"creature":
					b.start_next_wave()
					for i: int in 10:
						b.step()
					var enemy: EnemyPanel = EnemyPanel.new()
					enemy.setup(b)
					enemy.set_wide(wide)
					enemy.show_enemy(b.enemies[0].id)
					panel = enemy
				"preview", "strip", "preview boss", "strip many":
					if state == "strip":
						b.start_next_wave()
					if state == "preview boss" or state == "strip many":
						b.waves_started = b.wave_count() - 1
					if state == "strip many":
						b.phase = Battle.Phase.WAVE
					var preview: WavePreview = WavePreview.new()
					preview.set_wide(wide)
					var unseen: Array[StringName] = [&"grumblesack", &"flitter", &"scamp"]
					preview.set_unseen(unseen)
					preview.setup(b)
					if state == "preview boss":
						preview.toggle_row(&"scamp")
					panel = preview
				"hud wave":
					b.start_next_wave()
					for i: int in 120:
						b.step()
					hud.refresh()
					hud.set_paused(true)
					hud.set_speed(3)
				"boss creature":
					b = BattleFixtures.battle_with_first_wave([{"enemy": "grumblesack", "count": 1, "entrance": 1, "at_ms": 0, "every_ms": 1000}], &"r1_l6")
					b.start_next_wave()
					for i: int in 10:
						b.step()
					b.enemies[0].slow_pct = 40
					b.enemies[0].slow_ticks = 30
					var boss: EnemyPanel = EnemyPanel.new()
					boss.setup(b)
					boss.set_wide(wide)
					boss.show_enemy(b.enemies[0].id)
					hud.refresh(b)
					panel = boss
			column.add_child(hud)
			if panel != null:
				column.add_child(panel)
			await _frames()
			var where: String = "%s at %s" % [state, size]
			var column_rect: Rect2 = Rect2(column.global_position, Vector2(width, column.size.y))
			for node: Node in column.find_children("*", "BaseButton", true, false):
				var button: BaseButton = node as BaseButton
				if not button.is_visible_in_tree():
					continue
				var rect: Rect2 = button.get_global_rect()
				var label: String = "%s: button '%s'" % [where, str((button as Button).text)]
				check(rect.size.x >= Layout.MIN_TOUCH - 0.5 and rect.size.y >= Layout.MIN_TOUCH - 0.5, "%s is under 48 dp (%s)" % [label, rect.size])
				check(rect.position.x >= column_rect.position.x - 0.5 and rect.end.x <= column_rect.end.x + 0.5, "%s sticks out of the panel column %s" % [label, rect])
			# Nothing may lie outside the screen: every visible control, at any depth.
			var screen: Rect2 = Rect2(Vector2.ZERO, size)
			for node: Node in column.find_children("*", "Control", true, false):
				var control: Control = node as Control
				if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
					continue
				var box: Rect2 = control.get_global_rect()
				check(screen.grow(0.5).encloses(box), "%s: %s (%s) lies outside the screen %s" % [where, control.get_class(), control.name, box])
			for part: Control in [hud, panel]:
				if part != null:
					check(part.size.x <= width + 0.5, "%s: a panel is wider than its column (%s)" % [where, part.size.x])
					check(part.get_global_rect().end.y <= size.y, "%s: a panel runs off the screen bottom (%s)" % [where, part.get_global_rect().end.y])
			vp.queue_free()
	# A real tap on the Build button builds, and a real tap on Sell twice sells.
	var host: Array = _panel_host(COVER, true)
	var tap_vp: SubViewport = host[0]
	var tap_column: VBoxContainer = host[1]
	var live: Battle = BattleFixtures.battle()
	var spot: Vector2i = live.level.spots[0]
	var build_panel: BuildPanel = BuildPanel.new()
	build_panel.setup(live)
	build_panel.show_spot(spot)
	tap_column.add_child(build_panel)
	await _frames()
	_touch(tap_vp, build_panel.build_button.get_global_rect().get_center())
	check(live.tower_at(spot) != null, "a real tap on Build builds the tower")
	var tower_panel: TowerPanel = TowerPanel.new()
	tower_panel.setup(live)
	tower_panel.show_tower(spot)
	tap_column.remove_child(build_panel)
	tap_column.add_child(tower_panel)
	await _frames()
	_touch(tap_vp, tower_panel.sell_button.get_global_rect().get_center())
	check(live.tower_at(spot) != null, "the first real tap on Sell only asks")
	await _frames()
	_touch(tap_vp, tower_panel.sell_button.get_global_rect().get_center())
	check(live.tower_at(spot) == null, "the second real tap on Sell sells")
	tap_vp.queue_free()


# The App.

func _app() -> void:
	var vp: SubViewport = _viewport(COVER)
	var app: App = (load("res://scenes/ui/app.tscn") as PackedScene).instantiate() as App
	vp.add_child(app)
	await _frames()
	check(app.current_screen() is FrontDoor, "the App boots to the front door")
	check(not app.get_tree().quit_on_go_back, "the App handles the back button itself")
	_touch(vp, app.front_door().play_button.get_global_rect().get_center())
	check(app.current_screen() is ModeScreen, "a real tap on Play opens the mode screen")
	check(app.handle_back() == &"page", "back leaves the mode screen")
	_touch(vp, app.front_door().info_button.get_global_rect().get_center())
	await _frames()
	check(app.current_screen() is InfoScreen, "a real tap on Info opens Info")
	check((app.current_screen() as InfoScreen).scroll.scroll_vertical == 0, "Info opens at the top")
	app.handle_back()
	await _frames()
	_touch(vp, app.front_door().settings_button.get_global_rect().get_center())
	check(app.modal_count() == 1, "a real tap on the gear opens Settings")
	app.handle_back()
	check(app.modal_count() == 0, "back closes Settings")
	# A fold: the window changes shape, the front door follows, and the state stays.
	var door: FrontDoor = app.front_door()
	vp.size = Vector2i(INNER)
	await _frames()
	check(door.landscape, "an unfolded window switches to the landscape layout")
	vp.size = Vector2i(COVER)
	await _frames()
	check(not door.landscape, "and back to portrait")
	vp.queue_free()
