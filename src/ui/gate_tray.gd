# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name GateTray
extends BattlePanel
## The gate strip (RULES 7.1, 7.2, 7.6): how many gates are in hand, a gate to drag
## onto a socket, and the sentence that says gates are locked during a wave. Gate
## refusals (BattleText.refusal) show in its message box. A gate dragged from here
## is reported with global positions; the battle screen runs the drag.
##
## The strip is hidden on a level with no gates.

signal drag_began(global_point: Vector2)
signal drag_moved(global_point: Vector2)
signal drag_ended(global_point: Vector2)

var icon: GlyphIcon
var title_label: Label
var detail_label: Label

var _dragging: bool = false
var _pressing: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _state: String = ""


func _init() -> void:
	super()
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 18)
	icon = GlyphIcon.new(84.0).show_glyph(&"gate")
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 0)
	title_label = UiKit.heading("")
	text.add_child(title_label)
	detail_label = UiKit.label("", &"SoftLabel")
	text.add_child(detail_label)
	row.add_child(text)
	column.add_child(row)
	column.add_child(feedback_box)
	visible = false


## The explaining line shows in the roomy side panel. In portrait every pixel of height
## goes to the map, so the strip is one line.
func set_wide(value: bool) -> void:
	super(value)
	detail_label.visible = not value


func refresh() -> void:
	if battle == null:
		return
	var in_hand: int = battle.gates_in_hand
	var placed: int = battle.gates.size()
	visible = in_hand + placed > 0
	var text: String
	var detail: String
	if battle.phase != Battle.Phase.BUILD:
		text = "Gates: locked"
		detail = BattleText.refusal(&"gates_locked")
	elif in_hand > 0:
		text = "Gates: %d in hand" % in_hand
		detail = "Drag one onto a marked road, or tap a marked road."
	else:
		text = "Gates: all placed"
		detail = "Drag a gate to move it. Tap a gate to take it back."
	var state: String = "%s|%s" % [text, detail]
	if state == _state:
		return
	_state = state
	title_label.text = text
	detail_label.text = detail


## True while a gate drag started here is going on.
func is_dragging() -> bool:
	return _dragging


## Drops a drag in progress without reporting an end (a layout change).
func cancel_drag() -> void:
	_dragging = false
	_pressing = false


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressing = _can_drag()
			_dragging = false
			_press_at = _global_of(button.position)
		else:
			if _dragging:
				_dragging = false
				drag_ended.emit(_global_of(button.position))
			_pressing = false
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pressing:
		var at: Vector2 = _global_of(motion.position)
		if not _dragging and at.distance_to(_press_at) >= TapButton.DEADZONE:
			_dragging = true
			drag_began.emit(at)
		if _dragging:
			drag_moved.emit(at)


func _can_drag() -> bool:
	return battle != null and battle.phase == Battle.Phase.BUILD and battle.gates_in_hand > 0


func _global_of(local: Vector2) -> Vector2:
	return get_global_transform() * local


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		_dragging = false
		_pressing = false
