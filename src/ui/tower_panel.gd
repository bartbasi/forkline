# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TowerPanel
extends BattlePanel
## The panel for a tapped tower (RULES 4.6, 8.2, 9.3, 9.5): its real numbers and
## targeting, the upgrade with before and after numbers, the two tier 3 paths side
## by side, and selling with the exact refund.
##
## Choosing a tier 3 path is permanent, so a tap on a path only chooses it. The
## panel then says so and a second button confirms: the player is asked once.
## Selling asks the same way, with a second tap on the same button.
## Everything works while paused: the panel only sends commands to the Battle.

## The map should draw this tower's range ring (see BuildPanel.range_changed).
signal range_changed(cell: Vector2i, reach: int, boost: bool)
## The tower was sold.
signal sold(cell: Vector2i)

const NO_CELL: Vector2i = Vector2i(-1, -1)

var cell: Vector2i = NO_CELL
## The tier 3 path chosen but not yet confirmed, -1 for none.
var picked_spec: int = -1
var sell_armed: bool = false

var name_label: Label = null
var tier_label: Label = null
var aim_buttons: Array[TapButton] = []
var upgrade_button: TapButton = null
var confirm_button: TapButton = null
var path_cards: Array[TapRow] = []
var sell_button: TapButton = null
var refund_label: Label = null
var permanent_label: Label = null

var _signature: Array = []
var _open: bool = false
var _last_range: Array = []
var _refund_shown: int = 0


## Opens the panel on the tower at `new_cell`.
func show_tower(new_cell: Vector2i) -> void:
	cell = new_cell
	picked_spec = -1
	sell_armed = false
	_signature = []
	_last_range = []
	_open = true
	clear_feedback()
	refresh()


func is_open() -> bool:
	return _open


func set_wide(value: bool) -> void:
	if value != wide:
		super(value)
		_signature = []
		refresh()


## Closes the panel and hides the range ring.
func close() -> void:
	if not _open:
		return
	_open = false
	_last_range = []
	range_changed.emit(NO_CELL, 0, false)
	closed.emit()


## Changes the targeting mode, as a tap on its button does.
func set_aim(aim: TowerState.Aim) -> void:
	if battle == null or not _open:
		return
	sell_armed = false
	finish(battle.set_aim(cell, aim))
	_signature = []
	refresh()


## Chooses a tier 3 path to look at. Nothing is bought until it is confirmed.
func pick_path(spec: int) -> void:
	if battle == null or not _open:
		return
	sell_armed = false
	picked_spec = spec
	clear_feedback()
	refresh()


## Buys the next tier for a tier 1 tower, as a tap on the Upgrade button does.
func upgrade() -> void:
	if battle == null or not _open:
		return
	sell_armed = false
	var price: int = _price(-1)
	var result: StringName = battle.upgrade_tower(cell)
	finish(result, BattleText.shortfall(result, price, battle.gold))
	refresh()


## Buys the picked tier 3 path, as a tap on the confirm button does.
func confirm_path() -> void:
	if battle == null or not _open or picked_spec < 0:
		return
	var price: int = _price(picked_spec)
	var result: StringName = battle.upgrade_tower(cell, picked_spec)
	if finish(result, BattleText.shortfall(result, price, battle.gold)):
		picked_spec = -1
	refresh()


## The first tap arms the sale, the second sells. The refund is the exact amount.
func sell() -> void:
	if battle == null or not _open:
		return
	if not sell_armed:
		sell_armed = true
		_signature = []
		clear_feedback()
		refresh()
		return
	var refund: int = battle.sell_value(cell)
	var sold_cell: Vector2i = cell
	if finish(battle.sell_tower(cell)):
		sold.emit(sold_cell)
		_refund_shown = refund
		close()
	else:
		sell_armed = false
		_signature = []
		refresh()


## The gold the last sale paid, for the screen's floating text.
func last_refund() -> int:
	return _refund_shown


func refresh() -> void:
	if battle == null or not _open:
		return
	var tower: TowerState = battle.tower_at(cell)
	if tower == null:
		close()
		return
	var numbers: Dictionary = battle.tower_numbers(cell)
	var options: Array[Dictionary] = battle.upgrade_options(cell)
	if tower.tier != 2 and picked_spec >= 0:
		picked_spec = -1
	var signature: Array = [cell, wide, numbers, options, picked_spec, sell_armed, tower.spent_now, tower.spent_before]
	if signature == _signature:
		return
	_signature = signature
	_rebuild(tower, numbers, options)
	_announce_range(numbers)


func _rebuild(tower: TowerState, numbers: Dictionary, options: Array[Dictionary]) -> void:
	clear_column()
	aim_buttons.clear()
	path_cards.clear()
	upgrade_button = null
	confirm_button = null
	permanent_label = null
	var type: TowerType = battle.catalog.tower(tower.type)
	column.add_child(_header(tower, type))
	column.add_child(_stats(numbers, type))
	if type.kind == &"attack":
		column.add_child(_aim_row(tower))
	column.add_child(_upgrade_section(tower, type, numbers, options))
	column.add_child(_sell_section(tower))
	column.add_child(feedback_box)


func _header(tower: TowerState, type: TowerType) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.add_child(GlyphIcon.new(128.0).show_tower(tower.type, tower.tier, tower.spec))
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override(&"separation", 0)
	name_label = UiKit.heading(type.name)
	names.add_child(name_label)
	var tier_text: String = "Tier %d" % tower.tier
	if tower.tier >= 3:
		tier_text += ": %s" % type.spec_name(tower.spec)
	tier_label = UiKit.label(tier_text, &"SoftLabel")
	names.add_child(tier_label)
	row.add_child(names)
	var close_it: TapButton = UiKit.icon_button(&"close")
	close_it.tapped.connect(close)
	row.add_child(close_it)
	return row


func _stats(numbers: Dictionary, type: TowerType) -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 48)
	grid.add_theme_constant_override(&"v_separation", 6)
	var rows: Array[PackedStringArray] = BattleText.tower_rows(numbers, type.kind)
	rows.append(PackedStringArray(["Total spent", str(int(numbers["spent"]))]))
	if wide:
		# The narrow side panel leaves it out: the Sell button right below shows the same number.
		rows.append(PackedStringArray(["Sell value", str(int(numbers["sell"]))]))
	for row: PackedStringArray in rows:
		var r: StatRow = StatRow.pair(row[0], row[1])
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(r)
	return grid


func _aim_row(tower: TowerState) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	box.add_child(UiKit.label("Targeting", &"SoftLabel"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	for aim: int in BattleText.AIM_NAMES.size():
		var b: TapButton = UiKit.button(BattleText.aim_name(aim))
		mark_chosen(b, tower.aim == aim)
		b.tapped.connect(set_aim.bind(aim))
		aim_buttons.append(b)
		row.add_child(b)
	box.add_child(row)
	return box


func _upgrade_section(tower: TowerState, type: TowerType, numbers: Dictionary, options: Array[Dictionary]) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	if options.is_empty():
		box.add_child(UiKit.label("Fully upgraded.", &"SoftLabel"))
		return box
	var got_pct: int = int(numbers.get("got_pct", 0))
	if tower.tier == 1:
		var option: Dictionary = options[0]
		box.add_child(UiKit.label("Upgrade to tier 2", &"SoftLabel"))
		for change: Dictionary in BattleText.change_rows(option["before"], option["after"], type.kind, got_pct):
			box.add_child(StatRow.change(change["label"], change["before"], change["after"]))
		upgrade_button = UiKit.wrapped(UiKit.button("Upgrade for %d" % int(option["cost"]), &"PrimaryButton" if option["refusal"] == &"" else &"Button"))
		_lock_if_refused(upgrade_button, option["refusal"])
		upgrade_button.tapped.connect(upgrade)
		box.add_child(upgrade_button)
		return box
	if picked_spec < 0:
		box.add_child(UiKit.label("Pick a path for tier 3. The choice is permanent.", &"SoftLabel"))
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 14)
	for option: Dictionary in options:
		var card: TapRow = _path_card(type, option, got_pct)
		path_cards.append(card)
		cards.add_child(card)
	box.add_child(cards)
	if picked_spec >= 0:
		var chosen: Dictionary = _option_for(options, picked_spec)
		var note: HBoxContainer = HBoxContainer.new()
		note.add_theme_constant_override(&"separation", 12)
		var lock: TextureRect = TextureRect.new()
		lock.texture = IconTex.make(&"lock", 64)
		lock.custom_minimum_size = Vector2(52.0, 52.0)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.modulate = Palette.HONEY
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_child(lock)
		permanent_label = UiKit.label("This choice is permanent for this tower. Only selling it lets you choose again.", &"SoftLabel")
		permanent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.add_child(permanent_label)
		box.add_child(note)
		var ready: bool = chosen["refusal"] == &""
		confirm_button = UiKit.wrapped(UiKit.button("Choose %s for %d" % [type.spec_name(picked_spec), int(chosen["cost"])], &"PrimaryButton" if ready else &"Button"))
		_lock_if_refused(confirm_button, chosen["refusal"])
		confirm_button.tapped.connect(confirm_path)
		box.add_child(confirm_button)
	return box


func _path_card(type: TowerType, option: Dictionary, got_pct: int) -> TapRow:
	var spec: int = option["spec"]
	var affordable: bool = option["refusal"] == &""
	var card: TapRow = TapRow.new(&"CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen: bool = spec == picked_spec
	card.set_look(Palette.CARD if affordable else Palette.CARD_DIM, Palette.HONEY if chosen else Palette.INK_LINE, 12 if chosen else 4, 12)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", 8)
	top.add_child(GlyphIcon.new(80.0).show_tower(type.id, 3, spec))
	var path_name: Label = UiKit.label(type.spec_name(spec), &"CardLabel")
	path_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	path_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(path_name)
	card.body.add_child(top)
	card.body.add_child(UiKit.label(type.spec_info(spec), &"CardMutedLabel"))
	for change: Dictionary in BattleText.change_rows(option["before"], option["after"], type.kind, got_pct):
		card.body.add_child(StatRow.change(change["label"], change["before"], change["after"], &"CardMutedLabel", &"CardLabel", Palette.TEXT_DARK, 36))
	var cost_text: String = "Cost %d" % int(option["cost"])
	if not affordable and option["refusal"] == &"too_poor":
		cost_text += ", need %d more" % (int(option["cost"]) - battle.gold)
	card.body.add_child(UiKit.label(cost_text, &"CardLabel"))
	card.tapped.connect(pick_path.bind(spec))
	return card


func _sell_section(tower: TowerState) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	var refund: int = battle.sell_value(cell)
	refund_label = UiKit.label(BattleText.refund_text(tower.spent_now, tower.spent_before, battle.catalog.rules.refund_pct), &"SoftLabel")
	box.add_child(refund_label)
	if sell_armed:
		sell_button = UiKit.wrapped(UiKit.button("Tap again to sell for %d" % refund, &"PrimaryButton"))
	else:
		sell_button = UiKit.wrapped(UiKit.button("Sell for %d" % refund))
	sell_button.tapped.connect(sell)
	box.add_child(sell_button)
	return box


func _lock_if_refused(button: TapButton, refusal: StringName) -> void:
	if refusal == &"":
		return
	# The button stays tappable so a tap explains the refusal, and it wears a lock.
	button.icon = IconTex.make(&"lock", 56)
	for state: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color"]:
		button.add_theme_color_override(state, Palette.TEXT_SOFT)


func _option_for(options: Array[Dictionary], spec: int) -> Dictionary:
	for option: Dictionary in options:
		if option["spec"] == spec:
			return option
	return {}


func _price(spec: int) -> int:
	return int(_option_for(battle.upgrade_options(cell), spec).get("cost", 0))


## Tells the map this tower's range, when it changed.
func _announce_range(numbers: Dictionary) -> void:
	var kind: StringName = battle.catalog.tower(battle.tower_at(cell).type).kind
	var now: Array = [cell, int(numbers["reach"]), kind == &"boost"]
	if now != _last_range:
		_last_range = now
		range_changed.emit(cell, int(numbers["reach"]), kind == &"boost")
