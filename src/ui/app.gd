# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name App
extends Control
## The app glue (docs/ARCHITECTURE.md 3.6): boots to the front door, switches
## between screens, keeps panels above them, lays everything out for the window
## and handles the back button.
##
## Screens form a stack. Only the top one shows. Modals (Settings, Pause, a
## confirm) sit above the stack; a page opened from a modal hides the modals
## until the player comes back to where it started. The back button closes the
## top modal first, then goes back one page, and on the front door it quits.
## Everything is saved the moment it changes, so quitting loses nothing.

## The player turned sound on or off in Settings.
signal sound_changed(on: bool)
## Taps on the mode screen. The battle flow answers these (later waves).
signal continue_requested()
signal campaign_requested()
signal roguelite_requested()
signal daily_requested()

## Stars the roguelite and the daily need until the rules file says otherwise.
const RUN_STARS_DEFAULT: int = 12

var sound_on: bool = true
## rules.json keys, once the data is loaded. Only the Info guide uses them.
var rules: Dictionary = {}
## Creature and tower names by id, once the data is loaded. Only Info uses them.
var names: Dictionary = {}
var stars: int = 0
var runs_open: bool = false

var _backdrop: Backdrop
var _screens: Control
var _modal_layer: Control
var _stack: Array[ScreenFrame] = []
var _modals: Array[Modal] = []
var _front_door: FrontDoor
var _trash: Array[Node] = []
var _window: Vector2 = Vector2(1080.0, 2400.0)
var _safe: Rect2 = Rect2(0.0, 0.0, 1080.0, 2400.0)
## The stack size when a page first hid the modals; -1 when they are showing.
var _hidden_depth: int = -1


func _ready() -> void:
	build()
	get_tree().quit_on_go_back = false
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


## Builds the backdrop, the layers and the front door. _ready calls it; a test
## may call it first to work without a scene tree. It runs once.
func build() -> void:
	if _front_door != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build()
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_screens = _full_rect_control()
	add_child(_screens)
	_modal_layer = _full_rect_control()
	add_child(_modal_layer)
	_front_door = FrontDoor.new()
	_front_door.play_pressed.connect(open_mode)
	_front_door.info_pressed.connect(open_info)
	_front_door.about_pressed.connect(open_about)
	_front_door.settings_pressed.connect(open_settings)
	_screens.add_child(_front_door)
	_stack.append(_front_door)
	apply_layout(_window, _safe)


func _exit_tree() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.disconnect(_on_viewport_resized)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_pressed()
	elif what == NOTIFICATION_PREDELETE:
		for node: Node in _trash:
			if is_instance_valid(node):
				node.free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_pressed()


# Screens.

## The screen that is showing.
func current_screen() -> ScreenFrame:
	return _stack.back()


func screen_count() -> int:
	return _stack.size()


func modal_count() -> int:
	return _modals.size()


## The modal on top, or null.
func top_modal() -> Modal:
	return null if _modals.is_empty() else _modals.back()


## False while a page hides the modals.
func modals_showing() -> bool:
	return _modal_layer.visible


func front_door() -> FrontDoor:
	return _front_door


## Puts a screen on top of the stack. Only it shows until it is popped.
func push_screen(screen: ScreenFrame) -> void:
	if not _modals.is_empty() and _hidden_depth < 0:
		_hidden_depth = _stack.size()
		_modal_layer.visible = false
	_stack.back().visible = false
	_stack.append(screen)
	_screens.add_child(screen)
	screen.back_requested.connect(pop_screen)
	screen.apply_layout(_window, _safe)


## Removes the top screen. The front door is never removed.
func pop_screen() -> void:
	if _stack.size() <= 1:
		return
	var gone: ScreenFrame = _stack.pop_back()
	_screens.remove_child(gone)
	_discard(gone)
	_stack.back().visible = true
	if _hidden_depth == _stack.size():
		_hidden_depth = -1
		_modal_layer.visible = true


func open_mode() -> void:
	var screen: ModeScreen = ModeScreen.new()
	screen.set_runs(runs_open, stars, int(rules.get("run_stars", RUN_STARS_DEFAULT)))
	screen.continue_pressed.connect(func() -> void: continue_requested.emit())
	screen.campaign_pressed.connect(func() -> void: campaign_requested.emit())
	screen.roguelite_pressed.connect(func() -> void: roguelite_requested.emit())
	screen.daily_pressed.connect(func() -> void: daily_requested.emit())
	push_screen(screen)


func open_info() -> void:
	push_screen(InfoScreen.new(rules, names))


func open_about() -> void:
	var screen: AboutScreen = AboutScreen.new()
	screen.license_requested.connect(open_license)
	push_screen(screen)


## The license reader for one About row (a LicenseText kind).
func open_license(kind: StringName) -> void:
	var titles: Dictionary[StringName, String] = {
		LicenseText.FORKLINE: "Forkline",
		LicenseText.GODOT: "Godot Engine",
		LicenseText.FONT: "Outfit font",
	}
	push_screen(LicenseViewer.new(titles.get(kind, "License"), LicenseText.build(kind)))


# Modals.

func open_settings() -> void:
	var panel: SettingsPanel = SettingsPanel.new(sound_on)
	panel.sound_changed.connect(_on_sound_changed)
	panel.about_requested.connect(open_about)
	open_modal(panel)


## Shows a modal above everything. It frees itself from here when it closes.
func open_modal(modal: Modal) -> void:
	_modals.append(modal)
	_modal_layer.add_child(modal)
	modal.closed.connect(_modal_closed.bind(modal))
	modal.apply_layout(_window, _safe)


func _modal_closed(modal: Modal) -> void:
	if not _modals.has(modal):
		return
	_modals.erase(modal)
	_modal_layer.remove_child(modal)
	_discard(modal)


func _on_sound_changed(on: bool) -> void:
	sound_on = on
	sound_changed.emit(on)


# Back button.

## Does what the back button does and says what it did: &"modal" (closed or
## answered the top modal), &"page" (went back one page), or &"quit" (nothing
## left to close; the caller quits).
func handle_back() -> StringName:
	if not _modals.is_empty() and _modal_layer.visible:
		_modals.back().request_close()
		return &"modal"
	if _stack.size() > 1:
		pop_screen()
		return &"page"
	return &"quit"


func _back_pressed() -> void:
	if handle_back() == &"quit":
		get_tree().quit()


# Layout.

## Lays every screen and panel out for a window of this size. The App calls it
## on every resize; tests call it directly.
func apply_layout(window: Vector2, safe: Rect2) -> void:
	_window = window
	_safe = safe
	for screen: ScreenFrame in _stack:
		screen.apply_layout(window, safe)
	for modal: Modal in _modals:
		modal.apply_layout(window, safe)


func _on_viewport_resized() -> void:
	var viewport: Viewport = get_viewport()
	apply_layout(viewport.get_visible_rect().size, Layout.safe_rect(viewport))


func _full_rect_control() -> Control:
	var c: Control = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Frees a node that has been taken off the screen: at the end of the frame
## when the app is running. With no running scene tree (tests) the node waits in
## the trash and goes when the App itself is freed.
func _discard(node: Node) -> void:
	if is_inside_tree():
		node.queue_free()
	else:
		_trash.append(node)
