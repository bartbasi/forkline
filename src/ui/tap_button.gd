# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TapButton
extends Button
## The button every screen uses. It emits `tapped` only for a real tap: the
## finger went down and came up on the button, moved less than DEADZONE, and no
## scroll container above it moved in between. The end of a drag or a scroll
## never counts. Connect to `tapped`, not to `pressed`.

signal tapped()

## Finger travel allowed during a tap, in logical pixels (about 8 dp on the Fold5).
const DEADZONE: float = 24.0

var _down: bool = false
var _down_at: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _scroll_at: int = 0
var _tap_ok: bool = false


func _init() -> void:
	# Touch only: no focus ring, no keyboard presses.
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(Layout.MIN_TOUCH, Layout.MIN_TOUCH)


func _gui_input(event: InputEvent) -> void:
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if button_event.pressed:
			_down = true
			_down_at = button_event.position
			_travel = 0.0
			_scroll_at = _scroll_now()
			_tap_ok = false
		else:
			_tap_ok = _down and _travel < DEADZONE and _scroll_now() == _scroll_at
			_down = false
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _down:
		_travel = maxf(_travel, motion.position.distance_to(_down_at))


## Called by the button when a press ends on it. Only a clean tap goes on.
func _pressed() -> void:
	if _tap_ok:
		_tap_ok = false
		tapped.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		_down = false
		_tap_ok = false


## The scroll position of the nearest scroll container above, or 0.
func _scroll_now() -> int:
	var node: Node = get_parent()
	while node != null:
		var scroll: ScrollContainer = node as ScrollContainer
		if scroll != null:
			return scroll.scroll_vertical + scroll.scroll_horizontal * 100000
		node = node.get_parent()
	return 0
