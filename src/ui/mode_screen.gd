# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ModeScreen
extends PageFrame
## "Play" opens this: Campaign, Roguelite and Daily, with a Continue card on top
## when a game is saved. Roguelite and Daily show as "Coming in a later update" while
## the run mode is not built. Once it is, they show as locked, with the number of
## stars they need, until the App says they are open. The App fills in the
## numbers; this screen names no level, region or tower.

signal continue_pressed()
signal campaign_pressed()
signal roguelite_pressed()
signal daily_pressed()

var continue_button: TapButton
var campaign_button: TapButton
var roguelite_button: TapButton
var daily_button: TapButton

var _slot: VBoxContainer
var _runs_open: bool = false
var _runs_built: bool = true
var _stars_needed: int = 12
var _stars: int = 0


func _init() -> void:
	super("Play")
	_slot = VBoxContainer.new()
	column.add_child(_slot)
	campaign_button = UiKit.two_line_button("Campaign", "Hand-built levels. Earn stars to open more.", &"CardButton", &"CardLabel", &"CardMutedLabel")
	campaign_button.tapped.connect(func() -> void: campaign_pressed.emit())
	column.add_child(campaign_button)
	_build_runs()


## Shows the Continue card with a title and a line under it. Empty `title`
## removes the card.
func set_continue(title: String, detail: String) -> void:
	if continue_button != null:
		_slot.remove_child(continue_button)
		continue_button.queue_free()
		continue_button = null
	if title.is_empty():
		return
	continue_button = UiKit.two_line_button(title, detail, &"PrimaryButton", &"CardLabel", &"CardLabel")
	continue_button.tapped.connect(func() -> void: continue_pressed.emit())
	_slot.add_child(continue_button)


## Roguelite and Daily: not built yet, or open, or locked until `stars_needed` stars
## are earned. `built` false wins over everything else.
func set_runs(runs_open: bool, stars: int, stars_needed: int, built: bool = true) -> void:
	_runs_open = runs_open and built
	_runs_built = built
	_stars = stars
	_stars_needed = stars_needed
	if roguelite_button != null:
		column.remove_child(roguelite_button)
		roguelite_button.queue_free()
	if daily_button != null:
		column.remove_child(daily_button)
		daily_button.queue_free()
	_build_runs()


func _build_runs() -> void:
	roguelite_button = _run_card("Roguelite", "One run. Pick a card after each wave.")
	roguelite_button.tapped.connect(func() -> void: roguelite_pressed.emit())
	column.add_child(roguelite_button)
	daily_button = _run_card("Daily", "One run a day. The same for everyone.")
	daily_button.tapped.connect(func() -> void: daily_pressed.emit())
	column.add_child(daily_button)


func _run_card(title: String, detail: String) -> TapButton:
	if _runs_open:
		return UiKit.two_line_button(title, detail, &"CardButton", &"CardLabel", &"CardMutedLabel")
	var locked_text: String = "Locked. Needs %d stars, you have %d." % [_stars_needed, _stars]
	if not _runs_built:
		locked_text = "Coming in a later update."
	var b: TapButton = UiKit.two_line_button(title, locked_text, &"Button", &"Label", &"SoftLabel")
	b.disabled = true
	var margin: MarginContainer = b.get_child(0) as MarginContainer
	margin.add_theme_constant_override(&"margin_right", 160)
	var lock: TextureRect = TextureRect.new()
	lock.texture = IconTex.make(&"lock", 72)
	lock.modulate = Palette.TEXT_SOFT
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	lock.offset_left = -108.0
	lock.offset_right = -36.0
	lock.offset_top = -36.0
	lock.offset_bottom = 36.0
	b.add_child(lock)
	return b
