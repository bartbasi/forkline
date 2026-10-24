# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BattleScreen
extends ScreenFrame
## The battle: the map, the HUD, the panels and the touch input (docs/ARCHITECTURE.md
## 3.2, 3.6, 7.5). This is the only place that steps the sim and drains its events.
##
## Portrait: the HUD above the map, the wave preview below it, and the tower, build
## and creature panels as a bottom sheet over the lower map. The sheet never covers
## the HUD, and the map slides up so the tapped cell stays in sight. Landscape: the map
## on the left and one side column with the HUD, the open panel and the preview.
##
## Taps on a spot open the build or tower panel, a tap on a creature opens its
## numbers, and a tap on a gate socket places or takes back a gate. A gate can also be
## dragged (from the strip or from a socket) with the route lines showing the result,
## and a drop that would close every road is refused with the crossed out gate.

## The game should be saved: a build phase began, or the game was paused.
signal save_requested()
## Progress changed (a first sight was recorded).
signal progress_changed()
## The level was won, lost or abandoned. `result` is Battle.result() plus
## "abandoned" and "relaxed".
signal ended(result: Dictionary)
## "Back to menu" in Pause. The game stays saved.
signal left()

const NO_CELL: Vector2i = Vector2i(-1, -1)
const SIDE_WIDTH: float = 760.0
const SIDE_MIN: float = 560.0
## Panels keep this far from the screen edge. The map itself runs edge to edge.
const EDGE: float = 16.0
const GAP: float = 12.0
## A dragged gate snaps to a socket this close, in cells.
const SNAP_CELLS: float = 0.6
## The carried gate floats this far above the finger, in cells.
const GHOST_LIFT: float = 0.8
const PAN_RATE: float = 14.0

var battle: Battle = null
var audio: AudioService = null
var progress: Progress = null
## The App, which owns the modals. Null in a lone screen (tests), which then keeps its own.
var host: App = null
## Debug builds only: times every tick.
var probe: PerfProbe = null
var clock: BattleClock = BattleClock.new()

var map_area: Control
var map_view: MapView
var hud: BattleHud
var gate_tray: GateTray
var pause_strip: PauseStrip
var hint_banner: HintBanner
var preview: WavePreview
var build_panel: BuildPanel
var tower_panel: TowerPanel
var enemy_panel: EnemyPanel
var ghost: GateGhost

var _stage: Control
var _flow: BoxContainer
var _top_wrap: MarginContainer
var _top_box: VBoxContainer
var _bottom_wrap: MarginContainer
var _bottom_box: VBoxContainer
var _side: ScrollContainer
var _side_wrap: MarginContainer
var _side_box: VBoxContainer
var _sheet: VBoxContainer
var _sheet_scroll: ScrollContainer
var _arranged: int = -1

var _context: BattlePanel = null
var _selected: Vector2i = NO_CELL
var _hint_cell: Vector2i = NO_CELL
var _pause_panel: PausePanel = null
var _card: InfoCard = null
var _modals: Array[Modal] = []
## Closed modals of a screen that is not in a scene tree; freed with the screen.
var _modals_gone: Array[Modal] = []
var _routes_sig: Array = []
var _finished: bool = false

var _pressing: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _press_cell: Vector2i = NO_CELL
var _drag_active: bool = false
var _drag_from: Vector2i = NO_CELL
var _drag_target: Vector2i = NO_CELL
var _drag_sig: Array = []

var _map_base: Vector2 = Vector2.ZERO
var _pan: float = 0.0
var _pan_target: float = 0.0


func _init() -> void:
	super()
	pad = 0.0
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_flow = BoxContainer.new()
	_flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow.add_theme_constant_override(&"separation", 0)
	_stage.add_child(_flow)
	_build_map()
	_build_panels()
	_build_containers()
	_sheet = VBoxContainer.new()
	_sheet.alignment = BoxContainer.ALIGNMENT_END
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	var sheet_margin: MarginContainer = _wrap(_sheet, 0.0, GAP)
	sheet_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(sheet_margin)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.scroll_deadzone = int(TapButton.DEADZONE)
	_sheet_scroll.size_flags_horizontal = Control.SIZE_FILL
	_sheet_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	_sheet_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_sheet.add_child(_sheet_scroll)
	ghost = GateGhost.new()
	_stage.add_child(ghost)
	_connect_panels()


func _build_map() -> void:
	map_area = Control.new()
	map_area.mouse_filter = Control.MOUSE_FILTER_STOP
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.custom_minimum_size = Vector2(Layout.MIN_TOUCH, Layout.MIN_TOUCH)
	map_area.gui_input.connect(_on_map_input)
	map_area.resized.connect(_fit_map)
	map_view = MapView.new()
	# Behind every panel and modal, in front of the backdrop (which is at -10), so a
	# panel covers the thickets that reach past the map edge. The map's own layers
	# sit between -4 and -1.
	map_view.z_index = -5
	map_area.add_child(map_view)


func _build_panels() -> void:
	hud = BattleHud.new()
	gate_tray = GateTray.new()
	pause_strip = PauseStrip.new()
	hint_banner = HintBanner.new()
	preview = WavePreview.new()
	build_panel = BuildPanel.new()
	tower_panel = TowerPanel.new()
	enemy_panel = EnemyPanel.new()
	for panel: BattlePanel in [build_panel, tower_panel, enemy_panel]:
		panel.visible = false


func _build_containers() -> void:
	_top_box = VBoxContainer.new()
	_top_box.add_theme_constant_override(&"separation", GAP)
	_top_wrap = _wrap(_top_box, GAP, GAP)
	_bottom_box = VBoxContainer.new()
	_bottom_box.add_theme_constant_override(&"separation", GAP)
	_bottom_wrap = _wrap(_bottom_box, GAP, GAP)
	_side_box = VBoxContainer.new()
	_side_box.add_theme_constant_override(&"separation", GAP)
	_side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_wrap = _wrap(_side_box, GAP, GAP)
	_side_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side = ScrollContainer.new()
	_side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.scroll_deadzone = int(TapButton.DEADZONE)
	_side.add_child(_side_wrap)


func _wrap(inner: Control, top: float, bottom: float) -> MarginContainer:
	var wrap: MarginContainer = MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override(&"margin_left", roundi(EDGE))
	wrap.add_theme_constant_override(&"margin_right", roundi(EDGE))
	wrap.add_theme_constant_override(&"margin_top", roundi(top))
	wrap.add_theme_constant_override(&"margin_bottom", roundi(bottom))
	wrap.add_child(inner)
	return wrap


func _connect_panels() -> void:
	hud.speed_selected.connect(func(speed: int) -> void: clock.speed = speed)
	hud.pause_requested.connect(freeze)
	hud.resume_requested.connect(resume)
	pause_strip.menu_requested.connect(_open_pause_menu)
	hint_banner.closed.connect(_on_hint_closed)
	for panel: BattlePanel in [hud, gate_tray, build_panel, tower_panel]:
		panel.refused.connect(_on_refused)
	build_panel.range_changed.connect(_on_range_changed)
	tower_panel.range_changed.connect(_on_range_changed)
	build_panel.built.connect(_on_built)
	for panel: BattlePanel in [build_panel, tower_panel, enemy_panel]:
		panel.closed.connect(_on_panel_closed.bind(panel))
	enemy_panel.gone.connect(func(_id: int) -> void: enemy_panel.close())
	gate_tray.drag_began.connect(_on_tray_drag_began)
	gate_tray.drag_moved.connect(move_drag)
	gate_tray.drag_ended.connect(end_drag)


## Gives the screen its battle. Call once, before the screen is shown.
func setup(new_battle: Battle, new_audio: AudioService, new_progress: Progress) -> void:
	battle = new_battle
	audio = new_audio
	progress = new_progress
	map_view.setup(battle)
	hud.refresh(battle)
	hud.set_speed(clock.speed)
	for panel: BattlePanel in [gate_tray, preview, build_panel, tower_panel, enemy_panel]:
		panel.setup(battle)
	_show_unseen()
	if probe != null:
		probe.watch(battle, map_view)
	_fit_map()
	_check_sights()


# The clock.

func is_paused() -> bool:
	return clock.paused


## Freezes the clock and opens the Pause menu.
func pause() -> void:
	if _pause_panel != null:
		return
	_freeze_clock()
	save_requested.emit()
	_open_pause_menu()


## The HUD's pause button: freezes the clock and keeps the game open to build and look.
func freeze() -> void:
	_freeze_clock()
	pause_strip.visible = _pause_panel == null
	save_requested.emit()


func resume() -> void:
	clock.paused = false
	hud.set_paused(false)
	pause_strip.visible = false


func _freeze_clock() -> void:
	clock.paused = true
	hud.set_paused(true)
	if _drag_active:
		cancel_drag()


func _open_pause_menu() -> void:
	if _pause_panel != null:
		return
	pause_strip.visible = false
	_pause_panel = PausePanel.new()
	_pause_panel.resume_requested.connect(resume)
	_pause_panel.info_requested.connect(_open_info)
	_pause_panel.settings_requested.connect(_open_settings)
	_pause_panel.leave_requested.connect(_on_leave)
	_pause_panel.abandon_confirmed.connect(_on_abandon)
	_pause_panel.closed.connect(_on_pause_closed)
	_open_modal(_pause_panel)


func _on_pause_closed() -> void:
	_pause_panel = null


func _open_info() -> void:
	if host != null:
		host.open_info()


func _open_settings() -> void:
	if host != null:
		host.open_settings()


func _on_leave() -> void:
	left.emit()


func _on_abandon() -> void:
	if _finished:
		return
	_finished = true
	var result: Dictionary = battle.result()
	result["abandoned"] = true
	result["relaxed"] = battle.relaxed
	ended.emit(result)


## True while the Pause menu is open.
func pause_menu_open() -> bool:
	return _pause_panel != null


## True while a first sight card is open.
func card_open() -> bool:
	return _card != null


# Modals.

func _open_modal(modal: Modal) -> void:
	if host != null:
		host.open_modal(modal)
		return
	_modals.append(modal)
	add_child(modal)
	modal.closed.connect(_own_modal_closed.bind(modal))
	modal.apply_layout(window_size, safe)


func _own_modal_closed(modal: Modal) -> void:
	_modals.erase(modal)
	remove_child(modal)
	if is_inside_tree():
		modal.queue_free()
	else:
		_modals_gone.append(modal)


# Layout.

## From ScreenFrame. A size change during a wave pauses first (docs/ARCHITECTURE.md 7.5).
func apply_layout(new_window_size: Vector2, new_safe: Rect2) -> void:
	var resized: bool = window_size != Vector2.ZERO and not window_size.is_equal_approx(new_window_size)
	if resized and battle != null and battle.phase == Battle.Phase.WAVE and not clock.paused:
		pause()
	cancel_drag()
	super.apply_layout(new_window_size, new_safe)


func _relayout() -> void:
	_arrange()
	var wide: bool = not landscape
	preview.set_auto_expand(landscape)
	for panel: BattlePanel in [hud, gate_tray, pause_strip, hint_banner, preview, build_panel, tower_panel, enemy_panel]:
		panel.set_wide(wide)
	_side.custom_minimum_size.x = clampf(safe.size.x * 0.4, SIDE_MIN, SIDE_WIDTH)
	_place_context()
	_sheet.visible = _context != null and not landscape
	_fit_map.call_deferred()


## Puts the parts in the portrait or landscape arrangement. Nothing is freed.
func _arrange() -> void:
	var mode: int = 1 if landscape else 0
	if mode == _arranged:
		return
	_arranged = mode
	for node: Control in [hud, gate_tray, pause_strip, hint_banner, preview, build_panel, tower_panel, enemy_panel, map_area, _top_wrap, _bottom_wrap, _side]:
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
	_flow.vertical = not landscape
	if landscape:
		_flow.add_child(map_area)
		_flow.add_child(_side)
		for node: Control in [hud, gate_tray, pause_strip, hint_banner, preview]:
			_side_box.add_child(node)
	else:
		_flow.add_child(_top_wrap)
		_flow.add_child(map_area)
		_flow.add_child(_bottom_wrap)
		for node: Control in [hud, gate_tray, pause_strip]:
			_top_box.add_child(node)
		for node: Control in [hint_banner, preview]:
			_bottom_box.add_child(node)
	_context_parent_changed()


## Moves the open panel to where the layout keeps it: the sheet or the side column.
func _place_context() -> void:
	if _context == null:
		return
	var target: Node = _side_box if landscape else _sheet_scroll
	if _context.get_parent() != target:
		var parent: Node = _context.get_parent()
		if parent != null:
			parent.remove_child(_context)
		target.add_child(_context)
		if landscape:
			_side_box.move_child(_context, mini(3, _side_box.get_child_count() - 1))
	_context.visible = true
	_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _context_parent_changed() -> void:
	# Panels leave their old parent in _arrange; the open one is put back by _place_context.
	for panel: BattlePanel in [build_panel, tower_panel, enemy_panel]:
		var parent: Node = panel.get_parent()
		if parent != null:
			parent.remove_child(panel)
	_place_context()


## Fits the map into its slot, then slides it if the sheet would hide the selection.
func _fit_map() -> void:
	if battle == null:
		return
	map_view.fit(Rect2(Vector2.ZERO, map_area.size))
	_map_base = map_view.position
	_apply_pan()


## The map slides up so the selected cell stays above the sheet.
func _update_pan() -> void:
	_pan_target = 0.0
	if _context != null and not landscape and _selected.x >= 0 and _sheet.visible:
		var cell_px: float = map_view.scale.y * MapView.CELL
		var cell_top: float = _map_base.y + float(_selected.y) * cell_px
		var sheet_top: float = _sheet_scroll.global_position.y - map_area.global_position.y
		var need: float = cell_top + cell_px * 1.2 - sheet_top
		_pan_target = clampf(need, 0.0, maxf(0.0, cell_top - cell_px * 0.2))


func _apply_pan() -> void:
	map_view.position = Vector2(_map_base.x, _map_base.y - _pan)


func _update_sheet() -> void:
	_sheet.visible = _context != null and not landscape
	if not _sheet.visible:
		return
	var wanted: float = _context.get_combined_minimum_size().y
	var room: float = _stage.size.y - _top_wrap.size.y - GAP
	_sheet_scroll.custom_minimum_size.y = clampf(wanted, 0.0, maxf(room, Layout.MIN_TOUCH))


# Each frame.

func _process(delta: float) -> void:
	if battle != null and is_visible_in_tree():
		frame(delta)


## One frame of the battle (docs/ARCHITECTURE.md 3.2). Tests call it with their own delta.
func frame(delta: float) -> void:
	if battle == null:
		return
	if battle.phase == Battle.Phase.WAVE:
		for i: int in clock.advance(delta):
			if probe != null:
				var started: int = Time.get_ticks_usec()
				battle.step()
				probe.record_tick_usec(Time.get_ticks_usec() - started)
			else:
				battle.step()
	else:
		clock.reset()
	var events: Array[Dictionary] = battle.take_events()
	map_view.sync(clock.alpha())
	map_view.play_events(events)
	if audio != null:
		audio.play_events(events)
	hud.refresh()
	gate_tray.refresh()
	preview.refresh()
	if _context != null:
		_context.refresh()
	_handle(events)
	if _drag_active and battle.phase != Battle.Phase.BUILD:
		cancel_drag()
	if not _drag_active:
		_sync_routes()
	if is_inside_tree():
		_update_sheet()
		_update_pan()
		if delta <= 0.0 or absf(_pan_target - _pan) < 0.5:
			_pan = _pan_target
		else:
			_pan = lerpf(_pan, _pan_target, 1.0 - exp(-PAN_RATE * delta))
		_apply_pan()


func _handle(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		if e.get("kind") == &"build_started":
			save_requested.emit()
			_check_sights()
	if (battle.phase == Battle.Phase.WON or battle.phase == Battle.Phase.LOST) and not _finished:
		_finished = true
		var result: Dictionary = battle.result()
		result["abandoned"] = false
		result["relaxed"] = battle.relaxed
		ended.emit(result)


## Route lines show through the whole build phase and hide during waves (RULES 7.5).
func _sync_routes() -> void:
	var sig: Array = [battle.phase, battle.waves_started, battle.closed_cells()]
	if sig == _routes_sig:
		return
	_routes_sig = sig
	if battle.phase == Battle.Phase.BUILD:
		map_view.show_routes(battle.routes(battle.closed_cells()))
	else:
		map_view.show_routes([] as Array[Dictionary])


# First sights (RULES 9.2, 9.6).

func _check_sights() -> void:
	if battle == null or progress == null or battle.phase != Battle.Phase.BUILD:
		return
	var items: Array[Dictionary] = []
	var fresh: bool = battle.waves_started == 0 and battle.tick == 0
	if fresh:
		for id: StringName in battle.level.towers:
			if not progress.seen.has(id):
				items.append({"kind": &"tower", "id": id, "wave": 0})
	var next: int = battle.waves_started
	for entry: Dictionary in battle.wave_preview(next):
		var id: StringName = entry["enemy"]
		if not progress.seen.has(id) and not _has_item(items, id):
			items.append({"kind": &"enemy", "id": id, "wave": next})
	var changed: bool = false
	for item: Dictionary in items:
		progress.mark_seen(item["id"])
		changed = true
	if fresh and not battle.level.hint_text.is_empty() and not progress.seen.has(battle.level.id):
		progress.mark_seen(battle.level.id)
		changed = true
		hint_banner.show_hint(battle.level.hint_text)
		_hint_cell = battle.level.hint_cell
		map_view.show_hint(_hint_cell)
	if changed:
		progress_changed.emit()
		_show_unseen()
	if not items.is_empty():
		_show_card(items)


func _has_item(items: Array[Dictionary], id: StringName) -> bool:
	for item: Dictionary in items:
		if item["id"] == id:
			return true
	return false


func _show_card(items: Array[Dictionary]) -> void:
	if _card != null:
		return
	_card = InfoCard.new(battle, items)
	_card.closed.connect(_on_card_closed)
	_open_modal(_card)


func _on_card_closed() -> void:
	_card = null


## The preview tags the creatures this player has not met yet.
func _show_unseen() -> void:
	var ids: Array[StringName] = []
	if progress != null:
		for id: StringName in battle.catalog.enemy_ids():
			if not progress.seen.has(id):
				ids.append(id)
	preview.set_unseen(ids)


func _on_hint_closed() -> void:
	_hint_cell = NO_CELL
	map_view.show_hint(NO_CELL)


# Panel signals.

func _on_refused(_reason: StringName, _text: String) -> void:
	if audio != null:
		audio.play_ui(&"refuse")


func _on_range_changed(cell: Vector2i, reach: int, boost: bool) -> void:
	map_view.show_range(cell, reach, boost)


func _on_built(cell: Vector2i, _type: StringName) -> void:
	if cell == _hint_cell:
		_hint_cell = NO_CELL
		map_view.show_hint(NO_CELL)


func _on_panel_closed(panel: BattlePanel) -> void:
	if panel != _context:
		return
	_context = null
	_selected = NO_CELL
	panel.visible = false
	map_view.show_selection(NO_CELL)
	map_view.show_range(NO_CELL, 0, false)
	_sheet.visible = false


## The open build, tower or creature panel, or null.
func context_panel() -> BattlePanel:
	return _context


func selected_cell() -> Vector2i:
	return _selected


func _open_context(panel: BattlePanel, cell: Vector2i) -> void:
	if _context != null:
		_close_panel(_context)
	_context = panel
	_selected = cell
	map_view.show_selection(cell)
	_place_context()
	_sheet.visible = not landscape
	if audio != null:
		audio.play_ui(&"tap")


func _close_panel(panel: BattlePanel) -> void:
	if panel is BuildPanel:
		(panel as BuildPanel).close()
	elif panel is TowerPanel:
		(panel as TowerPanel).close()
	elif panel is EnemyPanel:
		(panel as EnemyPanel).close()


func close_context() -> void:
	if _context != null:
		_close_panel(_context)


# Taps.

func _on_map_input(event: InputEvent) -> void:
	if battle == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		var at: Vector2 = map_area.get_global_transform() * button.position
		if button.pressed:
			_pressing = true
			_press_at = at
			_travel = 0.0
			_press_cell = map_view.cell_at(at)
		elif _pressing:
			_pressing = false
			if _drag_active:
				end_drag(at)
			elif _travel < TapButton.DEADZONE:
				tap_at(map_view.cell_at(at), map_view.enemy_at(at))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pressing:
		var where: Vector2 = map_area.get_global_transform() * motion.position
		_travel = maxf(_travel, where.distance_to(_press_at))
		if not _drag_active and _travel >= TapButton.DEADZONE:
			_maybe_begin_drag(where)
		if _drag_active:
			move_drag(where)


## A tap at a cell, with the creature under the finger (-1 for none). Public so tests can tap.
func tap_at(cell: Vector2i, enemy_id: int = -1) -> void:
	if battle == null:
		return
	var kind: LevelData.Kind = battle.level.kind_at(cell) if cell.x >= 0 else LevelData.Kind.SCENERY
	if enemy_id >= 0:
		var enemy: EnemyState = battle.enemy_with_id(enemy_id)
		if enemy != null and (enemy.flying or kind != LevelData.Kind.SPOT):
			show_enemy(enemy_id)
			return
	match kind:
		LevelData.Kind.SPOT:
			if battle.tower_at(cell) != null:
				show_tower(cell)
			else:
				show_build(cell)
		LevelData.Kind.SOCKET:
			tap_socket(cell)
		_:
			close_context()


func show_build(cell: Vector2i) -> void:
	_open_context(build_panel, cell)
	build_panel.show_spot(cell)


func show_tower(cell: Vector2i) -> void:
	_open_context(tower_panel, cell)
	tower_panel.show_tower(cell)


func show_enemy(id: int) -> void:
	_open_context(enemy_panel, NO_CELL)
	enemy_panel.show_enemy(id)


## A tap on a socket: place a gate there, or take the gate on it back (RULES 7.2).
func tap_socket(cell: Vector2i) -> void:
	close_context()
	if battle.level.gates == 0 and battle.gates.is_empty():
		return
	var result: StringName
	if battle.phase != Battle.Phase.BUILD:
		result = &"gates_locked"
	elif _gate_at(cell) != null:
		result = battle.remove_gate(cell)
	else:
		result = battle.place_gate(cell)
	if not gate_tray.finish(result):
		map_view.show_refused(cell)


func _gate_at(cell: Vector2i) -> GateState:
	for gate: GateState in battle.gates:
		if gate.cell == cell:
			return gate
	return null


# The gate drag.

func _maybe_begin_drag(where: Vector2) -> void:
	if battle.phase != Battle.Phase.BUILD:
		return
	if battle.level.kind_at(_press_cell) != LevelData.Kind.SOCKET:
		return
	var gate: GateState = _gate_at(_press_cell)
	if gate != null:
		if gate.fixed:
			return
		begin_drag(_press_cell, where)
	elif battle.gates_in_hand > 0:
		begin_drag(NO_CELL, where)


func _on_tray_drag_began(where: Vector2) -> void:
	if battle.phase == Battle.Phase.BUILD and battle.gates_in_hand > 0:
		begin_drag(NO_CELL, where)


## Starts carrying a gate. `from` is the socket it was lifted from, or (-1, -1) for a
## new gate from the hand.
func begin_drag(from: Vector2i, where: Vector2) -> void:
	if battle == null or battle.phase != Battle.Phase.BUILD:
		return
	close_context()
	_drag_active = true
	_drag_from = from
	_drag_target = NO_CELL
	_drag_sig = []
	move_drag(where)


func is_dragging() -> bool:
	return _drag_active


func drag_target() -> Vector2i:
	return _drag_target


## The finger moved. The gate floats above it and snaps to a socket that is close.
func move_drag(where: Vector2) -> void:
	if not _drag_active:
		return
	var cell_px: float = _cell_px()
	var carried: Vector2 = where - Vector2(0.0, GHOST_LIFT * cell_px)
	var target: Vector2i = _socket_near(carried, cell_px)
	_drag_target = target
	var shown: Vector2 = _socket_center(target) if target.x >= 0 else carried
	var along: Vector2i = target if target.x >= 0 else (_drag_from if _drag_from.x >= 0 else _first_socket())
	var sealed: bool = _would_seal(target)
	ghost.show_at(shown, cell_px, MapArt.road_runs_vertically(battle.level.grid, along) if along.x >= 0 else false,
		MapArt.Gate.REFUSED if sealed else MapArt.Gate.CLOSED)
	var sig: Array = [target]
	if sig != _drag_sig:
		_drag_sig = sig
		_show_drag_routes(sealed)


## The finger lifted. A drop on a socket places or moves the gate. A gate lifted from a
## socket and dropped on the strip goes back to the hand. Anywhere else changes nothing.
func end_drag(where: Vector2) -> void:
	if not _drag_active:
		return
	move_drag(where)
	var target: Vector2i = _drag_target
	var from: Vector2i = _drag_from
	_drag_active = false
	ghost.hide_ghost()
	var result: StringName = &""
	if target.x >= 0:
		if from.x < 0:
			result = battle.place_gate(target)
		elif target != from:
			result = battle.move_gate(from, target)
	elif from.x >= 0 and gate_tray.visible and (gate_tray.get_global_rect().has_point(where) or gate_tray.get_global_rect().has_point(where - Vector2(0.0, GHOST_LIFT * _cell_px()))):
		result = battle.remove_gate(from)
	if result != &"" and not gate_tray.finish(result):
		map_view.show_refused(target if target.x >= 0 else from)
	_routes_sig = []
	_sync_routes()


## Drops a drag with no change (a layout change, the wave starting, the pause).
func cancel_drag() -> void:
	_pressing = false
	gate_tray.cancel_drag()
	if not _drag_active:
		return
	_drag_active = false
	ghost.hide_ghost()
	_routes_sig = []
	if battle != null:
		_sync_routes()


## The closed sockets as they would be if the carried gate were dropped where it hovers.
func _drag_closed(target: Vector2i) -> Array[Vector2i]:
	var closed: Array[Vector2i] = battle.closed_cells()
	if _drag_from.x >= 0:
		closed.erase(_drag_from)
	if target.x >= 0 and not closed.has(target) and (_gate_at(target) == null or target == _drag_from):
		closed.append(target)
	return closed


func _would_seal(target: Vector2i) -> bool:
	return target.x >= 0 and battle.seals(_drag_closed(target))


## The lines as they would be if the carried gate were dropped where it hovers. Over a
## socket that would close every road the crossed out gate shows instead.
func _show_drag_routes(sealed: bool) -> void:
	if sealed:
		map_view.show_refused(_drag_target)
		map_view.show_routes(battle.routes(battle.closed_cells()))
	else:
		map_view.show_routes(battle.routes(_drag_closed(_drag_target)))


func _cell_px() -> float:
	return map_view.get_global_transform().get_scale().x * MapView.CELL


func _socket_center(cell: Vector2i) -> Vector2:
	return map_view.get_global_transform() * ((Vector2(cell) + Vector2(0.5, 0.5)) * MapView.CELL)


func _socket_near(point: Vector2, cell_px: float) -> Vector2i:
	var best: Vector2i = NO_CELL
	var best_d: float = SNAP_CELLS * cell_px
	for socket: Vector2i in battle.level.sockets:
		var d: float = _socket_center(socket).distance_to(point)
		if d <= best_d:
			best_d = d
			best = socket
	return best


func _first_socket() -> Vector2i:
	return battle.level.sockets[0] if not battle.level.sockets.is_empty() else NO_CELL


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Parts that are not in the tree when the screen goes (the other layout's, the
		# closed panels) are freed here so nothing leaks.
		for node: Control in [hud, gate_tray, pause_strip, hint_banner, preview, build_panel, tower_panel, enemy_panel, map_area, _top_wrap, _bottom_wrap, _side, ghost, _sheet]:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
		for modal: Modal in _modals + _modals_gone:
			if is_instance_valid(modal) and modal.get_parent() == null:
				modal.free()
