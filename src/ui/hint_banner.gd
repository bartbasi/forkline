# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name HintBanner
extends BattlePanel
## A level's one line hint (RULES 9.6). It shows at the start of the level the first
## time it is played, next to a glow on the thing it talks about. A tap anywhere on it
## closes it, and the screen closes it when the first wave starts. It floats over the
## lower edge of the map, so it never takes height from the map. The hint always stays
## on the level card.

var text_label: Label
var close_it: TapButton
## The see-through button under the text: a tap on the banner closes it.
var tap_area: TapButton


func _init() -> void:
	super()
	tap_area = TapButton.new()
	tap_area.flat = true
	tap_area.custom_minimum_size = Vector2.ZERO
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_area.tapped.connect(func() -> void: closed.emit())
	add_child(tap_area)
	move_child(tap_area, 0)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 16)
	var mark: TextureRect = TextureRect.new()
	mark.texture = IconTex.make(&"arrow", 64)
	mark.custom_minimum_size = Vector2(52.0, 52.0)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.modulate = Palette.HONEY
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	text_label = UiKit.label("", &"Label")
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_label)
	close_it = close_button()
	row.add_child(close_it)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	closed.connect(func() -> void: visible = false)
	visible = false


## Shows the hint. An empty text hides the banner.
func show_hint(text: String) -> void:
	text_label.text = text
	visible = not text.is_empty()


func dismiss() -> void:
	if visible:
		closed.emit()
