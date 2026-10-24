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
const WATCHDOG_SECONDS: float = 400.0
## The Fold5 cover: 1080 logical px across 344 dp (docs/ARCHITECTURE.md 7.4).
const COVER_PX_PER_DP: float = 3.14
const BattleFixtures: GDScript = preload("res://tests/ui/battle_fixtures.gd")


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
	holder.theme = UiTheme.build()
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
	await _battle_screens()
	await _cell_floor()
	Links.opener = Callable()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


# Touch sizes.

const SCREEN_NAMES: PackedStringArray = [
	"front door", "mode screen", "mode screen open", "info", "about", "license viewer",
	"settings", "pause", "confirm", "level select", "level card", "level card saved", "end win", "end loss",
	"info card tower", "info card creature", "notice", "damaged",
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
			# Nothing may lie outside the screen: every visible control, at any depth. The one
			# exception is the two tall tier 3 states in the narrow side panel, which stacks
			# the path cards and scrolls (the side column is a scroll area).
			var scrolls: bool = not wide and (state == "paths" or state == "path picked")
			var screen: Rect2 = Rect2(Vector2.ZERO, size)
			for node: Node in column.find_children("*", "Control", true, false):
				if scrolls:
					break
				var control: Control = node as Control
				if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
					continue
				var box: Rect2 = control.get_global_rect()
				check(screen.grow(0.5).encloses(box), "%s: %s (%s) lies outside the screen %s" % [where, control.get_class(), control.name, box])
			for part: Control in [hud, panel]:
				if part != null:
					check(part.size.x <= width + 0.5, "%s: a panel is wider than its column (%s)" % [where, part.size.x])
					check(scrolls or part.get_global_rect().end.y <= size.y, "%s: a panel runs off the screen bottom (%s)" % [where, part.get_global_rect().end.y])
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
	check(live.tower_at(spot) != null, "a quick second tap on Sell does not sell")
	await create_timer(float(TowerPanel.SELL_DELAY_MS) / 1000.0 + 0.2).timeout
	_touch(tap_vp, tower_panel.sell_button.get_global_rect().get_center())
	check(live.tower_at(spot) == null, "a second real tap on Sell after the short wait sells")
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


# The battle screen in a real scene tree, at both Fold5 sizes.

const Fx: GDScript = preload("res://tests/ui/flow_fixtures.gd")
const BATTLE_TAGS: PackedStringArray = [
	"real_cover_build", "real_inner_build", "real_cover_touch", "real_inner_touch",
	"real_cover_drag", "real_inner_drag", "real_fold", "real_back",
]


func _battle_app(vp: SubViewport, size: Vector2, safe: Rect2, tag: String) -> App:
	Fx.wipe(tag)
	var made: App = (load("res://scenes/ui/app.tscn") as PackedScene).instantiate() as App
	made.game = BattleFixtures.game()
	made.store = SaveStore.new(Fx.dir(tag))
	made.audio = Fx.audio()
	made.end_delay = 0.0
	vp.add_child(made)
	await _frames()
	made.apply_layout(size, safe)
	Fx.mark_all_seen(made)
	return made


func _start_level(made: App, id: StringName) -> BattleScreen:
	made.start_level(id, false)
	await _frames(4)
	return made.battle_screen()


## Every visible control inside the viewport, and every button big enough.
func _inside_and_big(root: Node, size: Vector2, where: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, size).grow(0.6)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
			continue
		check(screen.encloses(control.get_global_rect()), "%s: %s (%s) lies outside the viewport %s" % [where, control.get_class(), control.name, control.get_global_rect()])
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button.is_visible_in_tree() and button.size.x > 0.0:
			check(button.size.x >= Layout.MIN_TOUCH - 0.5 and button.size.y >= Layout.MIN_TOUCH - 0.5, "%s: a button is under 48 dp (%s)" % [where, button.size])


func _cell_center(screen: BattleScreen, cell: Vector2i) -> Vector2:
	return screen.map_view.get_global_transform() * ((Vector2(cell) + Vector2(0.5, 0.5)) * MapView.CELL)


func _motion(vp: SubViewport, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(motion)


## The points of a straight line, for a finger that moves.
func _line(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in 9:
		out.append(from.lerp(to, float(i) / 8.0))
	return out


func _battle_screens() -> void:
	for pair: Array in [[COVER, COVER_SAFE, "cover"], [INNER, INNER_SAFE, "inner"]]:
		var size: Vector2 = pair[0]
		var safe: Rect2 = pair[1]
		var label: String = pair[2]
		await _battle_build_phase(size, safe, label)
		await _battle_panels_and_touch(size, safe, label)
		await _battle_gate_drag(size, safe, label)
	await _battle_fold()
	await _battle_back_and_pause()
	await _battle_end_delay()
	for tag: String in BATTLE_TAGS:
		Fx.wipe(tag)
	Fx.audio().free()


func _battle_build_phase(size: Vector2, safe: Rect2, label: String) -> void:
	var vp: SubViewport = _viewport(size)
	var made: App = await _battle_app(vp, size, safe, "real_%s_build" % label)
	var screen: BattleScreen = await _start_level(made, &"r1_l2")
	var where: String = "battle build phase at %s" % size
	_inside_and_big(screen, size, where)
	var cell_px: float = screen.map_view.scale.x * MapView.CELL
	check(cell_px >= (140.0 if not screen.landscape else 165.0), "%s: map cells are %.0f px" % [where, cell_px])
	check(screen.landscape == (label == "inner"), "%s: the layout follows the window" % where)
	var rect: Rect2 = screen.map_area.get_global_rect()
	check(rect.size.x >= 7.0 * cell_px - 1.0 and rect.size.y >= 10.0 * cell_px - 1.0, "%s: the whole map fits its slot" % where)
	if not screen.landscape:
		check(screen.hud.get_global_rect().end.y <= rect.position.y + 1.0, "%s: the HUD is above the map" % where)
		check(screen.hud.get_global_rect().position.y >= safe.position.y - 0.5, "%s: the HUD is inside the safe area" % where)
		check(screen.preview.get_global_rect().end.y <= safe.end.y + 0.5, "%s: the preview is inside the safe area" % where)
		check(screen.hud.call_button.get_global_rect().get_center().y < size.y * 0.5, "%s: the HUD is on top" % where)
		check(screen.preview.expanded, "%s: the preview is open in portrait too" % where)
	else:
		check(screen.hud.get_global_rect().position.x >= rect.end.x - 1.0, "%s: the HUD is in the side column" % where)
		check(screen.preview.get_global_rect().position.x >= rect.end.x - 1.0, "%s: the preview is in the side column" % where)
		check(screen.preview.expanded, "%s: the preview is open in landscape" % where)
	vp.queue_free()
	# A first sight card and the hint in a real layout.
	var vp2: SubViewport = _viewport(size)
	var fresh: App = (load("res://scenes/ui/app.tscn") as PackedScene).instantiate() as App
	Fx.wipe("real_%s_build" % label)
	fresh.game = BattleFixtures.game()
	fresh.store = SaveStore.new(Fx.dir("real_%s_build" % label))
	fresh.audio = Fx.audio()
	fresh.end_delay = 0.0
	vp2.add_child(fresh)
	await _frames()
	fresh.apply_layout(size, safe)
	fresh.start_level(&"r1_l1", false)
	await _frames(4)
	var first: BattleScreen = fresh.battle_screen()
	check(first.card_open(), "%s: level 1-1 opens its first sight card" % where)
	_inside_and_big(fresh.top_modal(), size, "%s first sight card" % where)
	for i: int in 3:
		(fresh.top_modal() as InfoCard).advance()
	await _frames(2)
	check(first.hint_banner.visible, "%s: the hint shows after the cards" % where)
	_inside_and_big(first, size, "%s with the hint" % where)
	vp2.queue_free()
	await _frames(2)


func _battle_panels_and_touch(size: Vector2, safe: Rect2, label: String) -> void:
	var vp: SubViewport = _viewport(size)
	var made: App = await _battle_app(vp, size, safe, "real_%s_touch" % label)
	var screen: BattleScreen = await _start_level(made, &"r1_l3")
	var b: Battle = screen.battle
	var where: String = "battle touches at %s" % size
	# A real tap on a build spot opens the build panel.
	var spot: Vector2i = b.level.spots[0]
	_touch(vp, _cell_center(screen, spot))
	await _frames(3)
	check(screen.context_panel() == screen.build_panel, "%s: a tap on a spot opens the build panel" % where)
	check(screen.selected_cell() == spot, "%s: and selects it" % where)
	if not screen.landscape:
		var sheet_top: float = screen.build_panel.get_global_rect().position.y
		check(sheet_top >= screen.hud.get_global_rect().end.y - 0.5, "%s: the sheet never covers the HUD (%s vs %s)" % [where, sheet_top, screen.hud.get_global_rect().end.y])
		_inside_and_big(screen.build_panel, size, "%s build panel" % where)
	# A real tap on Build builds.
	screen.build_panel.select_tower(&"pumpkin_catapult")
	await _frames(2)
	_touch(vp, screen.build_panel.build_button.get_global_rect().get_center())
	check(b.tower_at(spot) != null, "%s: a real tap on Build builds the tower" % where)
	await _frames(2)
	check(screen.context_panel() == null, "%s: the panel closed after building" % where)
	# The lowest spot: the sheet must not hide it, the map slides up.
	var lowest: Vector2i = b.level.spots[0]
	for cell: Vector2i in b.level.spots:
		if cell.y > lowest.y:
			lowest = cell
	b.gold = 2000
	b.place_tower(lowest, &"sling_post")
	b.upgrade_tower(lowest)
	await _frames(2)
	_touch(vp, _cell_center(screen, lowest))
	await _frames(40)
	check(screen.context_panel() == screen.tower_panel, "%s: a tap on a tower opens its panel" % where)
	if not screen.landscape:
		var sheet: Rect2 = screen.tower_panel.get_global_rect()
		var side: float = screen._cell_px()
		var cell_rect: Rect2 = Rect2(_cell_center(screen, lowest) - Vector2(side, side) * 0.5, Vector2(side, side))
		check(cell_rect.end.y <= sheet.position.y + 2.0, "%s: the tapped tower is above the sheet (%s vs %s)" % [where, cell_rect, sheet])
		check(cell_rect.position.y >= screen.hud.get_global_rect().end.y - 2.0, "%s: and below the HUD" % where)
		check(sheet.end.y <= safe.end.y + 0.5, "%s: the sheet is inside the safe area" % where)
		_inside_and_big(screen.tower_panel, size, "%s tower panel" % where)
	else:
		check(screen.tower_panel.get_global_rect().position.x >= screen.map_area.get_global_rect().end.x - 1.0, "%s: the panel is in the side column" % where)
	# A tap on bare ground closes the panel.
	var ground: Vector2i = Vector2i(-1, -1)
	var map_rect: Rect2 = screen.map_area.get_global_rect()
	var open_top: float = screen.tower_panel.get_global_rect().position.y if not screen.landscape else size.y
	for row: int in b.level.rows:
		for column: int in Sim.MAP_COLUMNS:
			var probe_cell: Vector2i = Vector2i(column, row)
			var at_cell: Vector2 = _cell_center(screen, probe_cell)
			if ground.x < 0 and b.level.kind_at(probe_cell) == LevelData.Kind.SCENERY and map_rect.has_point(at_cell) and at_cell.y < open_top - 60.0:
				ground = probe_cell
	check(ground.x >= 0, "%s: there is bare ground in sight" % where)
	_touch(vp, _cell_center(screen, ground))
	await _frames(2)
	check(screen.context_panel() == null, "%s: a tap on bare ground closes the panel" % where)
	# A creature panel during a wave, also while paused.
	b.upgrade_tower(lowest, 0)
	screen.hud.call_button.tapped.emit()
	screen.clock.speed = 3
	var guard: int = 0
	while b.enemies.is_empty() and guard < 300:
		await process_frame
		guard += 1
	await _frames(3)
	check(not b.enemies.is_empty(), "%s: a wave is running" % where)
	if not b.enemies.is_empty():
		screen.freeze()
		await _frames(40)
		var enemy: EnemyState = b.enemies[0]
		var view: MapView.CreatureView = screen.map_view._creatures[enemy.id]
		var at: Vector2 = screen.map_view.get_global_transform() * view.center
		check(screen.map_area.get_global_rect().has_point(at), "%s: the creature is on the map slot" % where)
		_touch(vp, at)
		await _frames(3)
		check(screen.context_panel() == screen.enemy_panel, "%s: a tap on a creature shows its numbers, also while paused" % where)
		if not screen.landscape:
			_inside_and_big(screen.enemy_panel, size, "%s creature panel" % where)
	vp.queue_free()
	await _frames(2)


func _battle_gate_drag(size: Vector2, safe: Rect2, label: String) -> void:
	var vp: SubViewport = _viewport(size)
	var made: App = await _battle_app(vp, size, safe, "real_%s_drag" % label)
	var data: Dictionary = BattleFixtures.game().levels[&"r1_l2"].to_data()
	data["gates"] = 2
	var level: LevelData = LevelData.from_data(data, BattleFixtures.game().catalog)
	var b: Battle = Battle.create(level, BattleFixtures.game().catalog, false, [] as Array[Dictionary])
	var saved: SavedGame = SavedGame.new()
	saved.mode = SavedGame.LEVEL
	saved.level_id = &"r1_l2"
	saved.battle = b
	made._begin(saved, false)
	await _frames(4)
	var screen: BattleScreen = made.battle_screen()
	var where: String = "gate drag at %s" % size
	var a: Vector2i = level.sockets[0]
	var c: Vector2i = level.sockets[1]
	var lift: Vector2 = Vector2(0.0, BattleScreen.GHOST_LIFT * screen._cell_px())
	# A tap places a gate, a tap takes it back.
	_touch(vp, _cell_center(screen, a))
	check(b.gates.size() == 1 and b.gates[0].cell == a, "%s: a real tap on a socket places a gate" % where)
	_touch(vp, _cell_center(screen, a))
	check(b.gates.is_empty(), "%s: a second tap takes it back" % where)
	# A drag from a socket with a gate moves it.
	_touch(vp, _cell_center(screen, a))
	await _frames(2)
	var path: Array[Vector2] = _line(_cell_center(screen, a), _cell_center(screen, c) + lift)
	_press(vp, path[0], true)
	for point: Vector2 in path:
		_motion(vp, point)
	await _frames(2)
	check(screen.is_dragging(), "%s: a drag from a placed gate is going on" % where)
	check(screen.drag_target() == c, "%s: the gate snaps to the other socket" % where)
	check(screen.ghost.visible, "%s: the carried gate shows" % where)
	_press(vp, path[path.size() - 1], false)
	await _frames(2)
	check(b.gates.size() == 1 and b.gates[0].cell == c, "%s: the drop moved the gate" % where)
	check(not screen.ghost.visible, "%s: the carried gate is gone after the drop" % where)
	# A second gate from the strip onto the first socket would close every road.
	var tray_from: Vector2 = screen.gate_tray.icon.get_global_rect().get_center()
	var drag_path: Array[Vector2] = _line(tray_from, _cell_center(screen, a) + lift)
	_press(vp, drag_path[0], true)
	for point: Vector2 in drag_path:
		_motion(vp, point)
	await _frames(2)
	check(screen.is_dragging(), "%s: a drag from the gate strip is going on" % where)
	check(screen.ghost.look == MapArt.Gate.REFUSED, "%s: the carried gate is crossed out over a refused socket" % where)
	_press(vp, drag_path[drag_path.size() - 1], false)
	await _frames(2)
	check(b.gates.size() == 1, "%s: the refused gate does not stay" % where)
	check(screen.gate_tray.feedback_text() == "That would close every road.", "%s: the sentence shows (%s)" % [where, screen.gate_tray.feedback_text()])
	# The gate strip takes a dropped gate back into the hand.
	var back_path: Array[Vector2] = _line(_cell_center(screen, c), screen.gate_tray.get_global_rect().get_center() + lift)
	_press(vp, back_path[0], true)
	for point: Vector2 in back_path:
		_motion(vp, point)
	_press(vp, back_path[back_path.size() - 1], false)
	await _frames(2)
	check(b.gates.is_empty(), "%s: a gate dropped on the strip goes back to the hand" % where)
	# Gates are locked during a wave.
	b.start_next_wave()
	await _frames(3)
	_touch(vp, _cell_center(screen, a))
	check(b.gates.is_empty(), "%s: no gate during a wave" % where)
	check(screen.gate_tray.feedback_text() == "Gates are locked until the wave is over.", "%s: the locked sentence shows" % where)
	vp.queue_free()
	await _frames(2)


func _battle_fold() -> void:
	var vp: SubViewport = _viewport(COVER)
	var made: App = await _battle_app(vp, COVER, COVER_SAFE, "real_fold")
	var screen: BattleScreen = await _start_level(made, &"r1_l2")
	var b: Battle = screen.battle
	Fx.build(screen, b.level.spots[0], &"sling_post")
	screen.close_context()
	_touch(vp, screen.hud.call_button.get_global_rect().get_center())
	screen.clock.speed = 2
	var guard: int = 0
	while b.enemies.size() < 2 and guard < 400:
		await process_frame
		guard += 1
	check(b.phase == Battle.Phase.WAVE and not screen.is_paused(), "fold: a wave is running")
	screen.tap_at(b.level.spots[0])
	var before: String = JSON.stringify(b.to_data())
	var tick: int = b.tick
	var parts: Array[int] = [screen.map_view.get_instance_id(), screen.hud.get_instance_id(), screen.tower_panel.get_instance_id()]
	vp.size = Vector2i(INNER)
	await _frames(3)
	check(screen.is_paused(), "fold: unfolding mid-wave pauses")
	check(made.top_modal() is PausePanel, "fold: on the Pause menu")
	check(screen.landscape, "fold: the window is near square, so the layout is landscape")
	check(screen.tower_panel.is_open() and screen.context_panel() == screen.tower_panel, "fold: the open panel stays open")
	check(screen.selected_cell() == b.level.spots[0], "fold: and the selection")
	check(JSON.stringify(b.to_data()) == before, "fold: the battle is untouched")
	check([screen.map_view.get_instance_id(), screen.hud.get_instance_id(), screen.tower_panel.get_instance_id()] == parts, "fold: no state node was replaced")
	check(screen.clock.speed == 2, "fold: the speed stays")
	await _frames(20)
	check(b.tick == tick, "fold: nothing moved while paused")
	var map_rect: Rect2 = screen.map_area.get_global_rect()
	check(map_rect.end.x <= INNER.x and screen.hud.get_global_rect().position.x >= map_rect.end.x - 1.0, "fold: map left, side column right")
	made.handle_back()
	await _frames(2)
	check(not screen.is_paused(), "fold: Resume goes on")
	await _frames(10)
	check(b.tick > tick, "fold: and time runs again")
	vp.size = Vector2i(COVER)
	await _frames(3)
	check(screen.is_paused() and not screen.landscape, "fold: folding again pauses and returns to portrait")
	check(screen.tower_panel.is_open(), "fold: still the same open panel")
	vp.queue_free()
	await _frames(2)


func _battle_back_and_pause() -> void:
	var vp: SubViewport = _viewport(COVER)
	var made: App = await _battle_app(vp, COVER, COVER_SAFE, "real_back")
	var screen: BattleScreen = await _start_level(made, &"r1_l1")
	check(made.handle_back() == &"modal", "back: in a battle opens Pause")
	await _frames(3)
	var pause: PausePanel = made.top_modal() as PausePanel
	check(pause != null, "back: the Pause menu is up")
	if pause != null:
		_inside_and_big(pause, COVER, "back: Pause over a battle")
		recorder.urls.clear()
		var coffee: CoffeeButton = pause.find_children("*", "CoffeeButton", true, false)[0] as CoffeeButton
		_touch(vp, coffee.get_global_rect().get_center())
		check(recorder.urls == ([Links.COFFEE_URL] as Array[String]), "back: the quiet coffee row in Pause hands over the address once, got %s" % [recorder.urls])
	var coffee_in_battle: int = 0
	for node: Node in screen.find_children("*", "CoffeeButton", true, false):
		coffee_in_battle += 1
	check(coffee_in_battle == 0, "back: the coffee button is not on the play screen")
	made.handle_back()
	await _frames(2)
	check(made.top_modal() == null and not screen.is_paused(), "back: back again resumes")
	vp.queue_free()
	await _frames(2)


## The end panel waits a moment after the last creature, and the back button skips the wait.
func _battle_end_delay() -> void:
	var vp: SubViewport = _viewport(COVER)
	var made: App = await _battle_app(vp, COVER, COVER_SAFE, "real_back")
	made.end_delay = 0.3
	var screen: BattleScreen = await _start_level(made, &"r1_l1")
	var win: Dictionary = {"won": true, "stars": 3, "lives_left": 19, "waves_cleared": 8, "abandoned": false, "relaxed": false}
	made._on_battle_ended(win)
	check(made.end_pending() and made.top_modal() == null, "end: the panel waits")
	check(made.saved_games.is_empty(), "end: but the saved game is already gone, so a kill cannot undo the win")
	check(made.progress.cleared(&"r1_l1"), "end: and the stars are already recorded")
	await _frames(5)
	check(made.top_modal() == null, "end: still waiting")
	await create_timer(0.5).timeout
	await _frames(3)
	check(made.top_modal() is EndPanel, "end: the panel shows after the delay")
	check(screen != null and made.end_pending() == false, "end: nothing is pending any more")
	_inside_and_big(made.top_modal(), COVER, "end panel over a battle")
	vp.queue_free()
	await _frames(2)


# The map cell floor (hard rule): on the Fold5 cover in portrait, map cells stay at least
# 48 dp in every state, on every region 1 map and on a 13 row map.

const TALL_GRID: PackedStringArray = [
	"...1...", "...#...", ".o.#.o.", ".#####.", ".G...G.", ".#.o.#.", ".#####.",
	"..o#o..", "...#...", ".o.#.o.", "...#...", "...#...", "..oB...",
]


## A real level with its map swapped for 13 rows.
func _tall_battle() -> Battle:
	var data: Dictionary = BattleFixtures.game().levels[&"r1_l5"].to_data()
	data["grid"] = Array(TALL_GRID)
	data["hint"] = {"text": "Tap a glowing spot to build a tower by the road.", "cell": [3, 5]}
	var level: LevelData = LevelData.from_data(data, BattleFixtures.game().catalog)
	check(level != null, "the 13 row test map is a valid level")
	if level == null:
		return null
	return Battle.create(level, BattleFixtures.game().catalog, false, [] as Array[Dictionary])


func _all_seen() -> Progress:
	var progress: Progress = Progress.new()
	for id: StringName in BattleFixtures.game().catalog.tower_ids():
		progress.mark_seen(id)
	for id: StringName in BattleFixtures.game().catalog.enemy_ids():
		progress.mark_seen(id)
	for id: StringName in BattleFixtures.game().levels:
		progress.mark_seen(id)
	return progress


func _cell_dp(screen: BattleScreen) -> float:
	return screen.map_view.get_global_transform().get_scale().x * MapView.CELL / COVER_PX_PER_DP


## Puts the screen in one state of the mix and checks the cell floor and the layout.
func _floor_state(screen: BattleScreen, label: String, hint: bool, folded: bool, paused: bool, panel: int, notes: bool, wave: bool) -> void:
	var b: Battle = screen.battle
	if wave and b.phase == Battle.Phase.BUILD:
		b.start_next_wave()
		BattleFixtures.steps(b, 4)
	screen.clock.speed = 1
	if paused:
		screen.freeze()
	else:
		screen.resume()
	if hint:
		screen.hint_banner.show_hint(b.level.hint_text)
		screen.map_view.show_hint(b.level.hint_cell)
	else:
		screen.hint_banner.dismiss()
	if screen.preview.expanded == folded:
		screen.preview.toggle()
	screen.close_context()
	if panel == 1:
		for cell: Vector2i in b.level.spots:
			if b.tower_at(cell) == null:
				screen.show_build(cell)
	elif panel == 2:
		screen.show_tower(b.towers[0].cell)
	if notes:
		screen.hud.show_feedback("The wave is still arriving.")
		screen.gate_tray.show_feedback("Gates are locked until the wave is over.")
	else:
		screen.hud.clear_feedback()
		screen.gate_tray.clear_feedback()
	await _frames(3)
	var where: String = "%s: hint %s, preview %s, paused %s, panel %d, notes %s, wave %s" % [label, hint, "folded" if folded else "open", paused, panel, notes, wave]
	check(_cell_dp(screen) >= 48.0, "cells are %.1f dp (%s)" % [_cell_dp(screen), where])
	# The map as laid out, before the sheet slides it up to show a selected cell.
	var origin: Vector2 = screen.map_area.get_global_rect().position + screen._map_base
	var map_rect: Rect2 = Rect2(origin, Vector2(float(Sim.MAP_COLUMNS), float(b.level.rows)) * MapView.CELL * screen.map_view.get_global_transform().get_scale().x)
	check(map_rect.position.y >= screen.hud.get_global_rect().end.y - 1.0, "the map starts under the HUD (%s)" % where)
	check(map_rect.end.y <= COVER_SAFE.end.y + 1.0, "the whole map is inside the safe area (%s)" % where)
	check(map_rect.position.x >= -0.5 and map_rect.end.x <= COVER.x + 0.5, "the map fits the width (%s)" % where)
	check(screen.hud.get_global_rect().position.y >= COVER_SAFE.position.y - 0.5, "the HUD is inside the safe area (%s)" % where)
	for part: Control in [screen.hint_banner, screen.gate_tray, screen.pause_strip, screen.preview, screen.hud.feedback_box]:
		if part.is_visible_in_tree():
			var r: Rect2 = part.get_global_rect()
			check(r.position.y >= screen.hud.get_global_rect().end.y - 1.0, "the dock never covers the HUD (%s)" % where)
			check(r.end.y <= COVER_SAFE.end.y + 1.0, "the dock is inside the safe area (%s)" % where)
	_inside_and_big(screen, COVER, where)


func _cell_floor() -> void:
	var level_ids: Array[String] = ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6", "tall"]
	for level_id: String in level_ids:
		var b: Battle = _tall_battle() if level_id == "tall" else BattleFixtures.battle(StringName(level_id))
		if b == null:
			continue
		b.gold = 5000
		for i: int in mini(2, b.level.spots.size()):
			b.place_tower(b.level.spots[i], &"sling_post")
		var vp: SubViewport = _viewport(COVER)
		var screen: BattleScreen = BattleScreen.new()
		screen.setup(b, null, _all_seen())
		await _hosted(vp, screen, COVER, COVER_SAFE)
		check(not screen.landscape, "%s: the cover is portrait" % level_id)
		var full: bool = level_id == "tall" or level_id == "r1_l5"
		if full:
			for hint: bool in [true, false]:
				for folded: bool in [false, true]:
					for paused: bool in [false, true]:
						for panel: int in [0, 1, 2]:
							for notes: bool in [false, true]:
								await _floor_state(screen, level_id, hint, folded, paused, panel, notes, false)
			# A running wave too: the strip, the panels and the messages.
			for folded: bool in [true, false]:
				for paused: bool in [false, true]:
					for panel: int in [0, 2]:
						await _floor_state(screen, level_id, false, folded, paused, panel, true, true)
		else:
			await _floor_state(screen, level_id, true, false, false, 0, false, false)
			await _floor_state(screen, level_id, true, false, true, 1, true, false)
			await _floor_state(screen, level_id, false, true, true, 0, true, true)
		vp.queue_free()
		await _frames(2)
