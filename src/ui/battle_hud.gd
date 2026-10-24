# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BattleHud
extends BattlePanel
## The HUD (RULES 4.7 to 4.9, 9.7): lives, gold, the wave, the speed 1x 2x 3x,
## pause, and the button that starts the next wave. In a build phase it reads
## "Start wave N". During a wave it calls the next wave early and shows the gold
## bonus for doing so, updated live. Calling works while paused.
##
## The speed and the paused look are only shown here: the screen owns the clock.

## The player picked a speed.
signal speed_selected(speed: int)
## The pause button was tapped while the game runs.
signal pause_requested()
## The pause button was tapped while the game is paused.
signal resume_requested()

var lives_label: Label
var gold_label: Label
var wave_label: Label
var pause_button: TapButton
var speed_buttons: Array[TapButton] = []
var call_button: TapButton

var speed: int = 1
var paused: bool = false

var _stats: HBoxContainer
var _row_top: HBoxContainer
var _row_mid: HBoxContainer
var _row_call: HBoxContainer
var _wide: bool = true
var _call_state: String = ""
## A part that sits in the first row, between the numbers and the pause button: the
## gate chip in portrait. Null for none.
var _gate_slot: Control = null


func _init() -> void:
	super()
	# Snug: the HUD is the one part that takes height from the map.
	add_theme_stylebox_override(&"panel", UiKit.box(Palette.PANEL, Palette.PANEL_EDGE, 3, 34, 10))
	_row_top = HBoxContainer.new()
	_row_top.add_theme_constant_override(&"separation", 12)
	_row_mid = HBoxContainer.new()
	_row_mid.add_theme_constant_override(&"separation", 12)
	_row_call = HBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	column.add_child(_row_top)
	column.add_child(_row_mid)
	column.add_child(_row_call)
	column.add_child(feedback_box)
	_stats = HBoxContainer.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.add_theme_constant_override(&"separation", 10)
	lives_label = _stat(&"heart")
	gold_label = _stat(&"coin")
	wave_label = _stat(&"moon")
	pause_button = UiKit.icon_button(&"pause")
	pause_button.tapped.connect(_on_pause)
	for value: int in [1, 2, 3]:
		var b: TapButton = UiKit.button("%dx" % value)
		b.custom_minimum_size = Vector2(Layout.MIN_TOUCH, Layout.MIN_TOUCH)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.tapped.connect(_on_speed.bind(value))
		speed_buttons.append(b)
	call_button = UiKit.wrapped(UiKit.button(""))
	call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_button.tapped.connect(_on_call)
	_arrange(true)
	_show_speed()


## True: the portrait arrangement, two rows. False: the narrow side panel of the
## landscape layout, three rows.
func set_wide(value: bool) -> void:
	wide = value
	if value != _wide:
		_arrange(value)


## Puts a part (the gate chip) in the first row of the portrait arrangement, or takes it
## out again with null. The caller removes it from its old parent first.
func set_gate_slot(node: Control) -> void:
	_gate_slot = node
	_arrange(_wide)


## Shows the speed the clock runs at.
func set_speed(value: int) -> void:
	if value >= 1 and value <= 3:
		speed = value
		_show_speed()


## Shows whether the clock is frozen: the pause button turns into a play button.
func set_paused(value: bool) -> void:
	paused = value
	pause_button.icon = IconTex.make(&"play" if paused else &"pause", 72)


## Reads the Battle: lives, gold, wave and the call button. Pass the Battle on the first call.
func refresh(new_battle: Battle = null) -> void:
	if new_battle != null:
		battle = new_battle
	if battle == null:
		return
	lives_label.text = str(maxi(battle.lives, 0))
	gold_label.text = str(battle.gold)
	wave_label.text = "Wave %d/%d" % [BattleText.wave_number(battle), battle.wave_count()]
	_refresh_call()


func _stat(glyph: StringName) -> Label:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(GlyphIcon.new(56.0).show_glyph(glyph))
	var l: Label = UiKit.label("0")
	l.add_theme_font_override(&"font", UiTheme.font(UiTheme.WEIGHT_BOLD))
	l.add_theme_font_size_override(&"font_size", UiTheme.FONT_BUTTON)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(l)
	_stats.add_child(box)
	return l


func _arrange(is_wide: bool) -> void:
	_wide = is_wide
	var movers: Array[Control] = [_stats, pause_button, call_button]
	if _gate_slot != null:
		movers.append(_gate_slot)
	movers.append_array(speed_buttons)
	for node: Control in movers:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
	_row_top.add_child(_stats)
	if is_wide:
		if _gate_slot != null:
			_row_top.add_child(_gate_slot)
		_row_top.add_child(pause_button)
		for b: TapButton in speed_buttons:
			_row_mid.add_child(b)
		_row_mid.add_child(call_button)
		_row_call.visible = false
	else:
		for b: TapButton in speed_buttons:
			_row_mid.add_child(b)
		_row_mid.add_child(pause_button)
		_row_call.add_child(call_button)
		_row_call.visible = true


func _show_speed() -> void:
	for i: int in speed_buttons.size():
		var chosen: bool = speed == i + 1
		var b: TapButton = speed_buttons[i]
		# The chosen speed has a honey fill, a thick ink border and heavy type:
		# three signals, so color is never the only one.
		var box: StyleBoxFlat = _speed_box(chosen)
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			b.add_theme_stylebox_override(state, box)
		var text_color: Color = Palette.TEXT_DARK if chosen else Palette.TEXT_LIGHT
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			b.add_theme_color_override(state, text_color)
		b.add_theme_font_override(&"font", UiTheme.font(UiTheme.WEIGHT_HEAVY if chosen else UiTheme.WEIGHT_REGULAR))


func _speed_box(chosen: bool) -> StyleBoxFlat:
	if chosen:
		return UiKit.box(Palette.HONEY, Palette.INK_LINE, 10, UiTheme.RADIUS, 8)
	return UiKit.box(Palette.PANEL_RAISED, Palette.PANEL_EDGE, 4, UiTheme.RADIUS, 8)


func _refresh_call() -> void:
	var info: Dictionary = battle.next_wave_info()
	var refusal: StringName = info["refusal"]
	var next_number: int = battle.waves_started + 1
	var text: String
	var primary: bool
	if battle.phase == Battle.Phase.BUILD and refusal == &"":
		text = "Start wave %d" % next_number
		primary = true
	elif refusal == &"":
		text = "Call wave %d  +%d" % [next_number, int(info["bonus"])]
		primary = true
	elif refusal == &"no_more_waves":
		text = "Last wave is out"
		primary = false
	elif refusal == &"over":
		text = "Battle over"
		primary = false
	else:
		text = "Call wave %d" % next_number
		primary = false
	var state: String = "%s|%s" % [text, primary]
	if state == _call_state:
		return
	_call_state = state
	call_button.text = text
	call_button.theme_type_variation = &"PrimaryButton" if primary else &"Button"
	# A call that cannot be made yet carries a lock, so it never differs by color alone.
	call_button.icon = null if primary else IconTex.make(&"lock", 56)
	call_button.add_theme_color_override(&"icon_normal_color", Palette.TEXT_SOFT)
	call_button.add_theme_color_override(&"icon_hover_color", Palette.TEXT_SOFT)
	call_button.add_theme_color_override(&"icon_pressed_color", Palette.TEXT_SOFT)


func _on_speed(value: int) -> void:
	set_speed(value)
	speed_selected.emit(value)


func _on_pause() -> void:
	if paused:
		resume_requested.emit()
	else:
		pause_requested.emit()


func _on_call() -> void:
	if battle == null:
		return
	var result: StringName = battle.start_next_wave()
	if finish(result):
		refresh()
