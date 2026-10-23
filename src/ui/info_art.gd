# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name InfoArt
extends Control
## The small real examples in the Info guide. Each one is drawn by the same
## src/theme/ code the game uses, so what the guide shows is what the player
## will see. Kinds: walk, hud, spots, tiers, towers, creatures, gates, signals,
## stars. Captions (names under towers and creatures) are optional: the guide
## passes them only when the data has names, and draws shapes alone otherwise.

## Height of each kind as a share of its width.
const RATIOS: Dictionary[StringName, float] = {
	&"walk": 0.4286, &"hud": 0.30, &"spots": 0.36, &"tiers": 0.30, &"towers": 0.34,
	&"creatures": 0.50, &"gates": 0.7143, &"signals": 0.62, &"stars": 0.20,
}
const WALK_GRID: PackedStringArray = ["..o....", "1#####B", "....o.."]
const GATES_GRID: PackedStringArray = ["...1...", "...#...", ".#####.", ".G.o.G.", ".##B##."]
const GATES_ROUTE: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(5, 3), Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4),
]

var kind: StringName
var captions: PackedStringArray


func _init(art_kind: StringName, art_captions: PackedStringArray = PackedStringArray()) -> void:
	kind = art_kind
	captions = art_captions
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## The example is as tall as its kind needs for this width.
func fit_width(width: float) -> void:
	custom_minimum_size = Vector2(width, width * float(RATIOS.get(kind, 0.4)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	match kind:
		&"walk":
			_walk()
		&"hud":
			_hud()
		&"spots":
			_spots()
		&"tiers":
			_tiers()
		&"towers":
			_towers()
		&"creatures":
			_creatures()
		&"gates":
			_gates()
		&"signals":
			_signals()
		&"stars":
			_stars()


# Examples.

func _walk() -> void:
	var cell: float = size.x / 7.0
	MapArt.draw_ground(self, WALK_GRID, cell)
	_walker(&"scamp", Vector2(3.4, 1.5), cell, 1)
	_walker(&"pip", Vector2(4.5, 1.5), cell, 2)
	_walker(&"skitter", Vector2(2.2, 1.5), cell, 3)


func _hud() -> void:
	var w: float = size.x
	var h: float = size.y
	var chip_w: float = (w - 2.0 * 24.0) / 3.0
	var chip_h: float = h * 0.42
	var glyphs: Array[StringName] = [&"heart", &"coin", &"moon"]
	var values: PackedStringArray = ["20", "150", "3 / 10"]
	for i: int in 3:
		var rect: Rect2 = Rect2(float(i) * (chip_w + 24.0), 0.0, chip_w, chip_h)
		_chip(rect, Palette.PANEL, Palette.PANEL_EDGE)
		Silhouettes.draw_glyph(self, glyphs[i], rect.position + Vector2(chip_h * 0.55, chip_h * 0.5), chip_h * 0.6)
		_text(values[i], rect.position + Vector2(chip_h * 1.05, chip_h * 0.5), UiTheme.FONT_BODY, Palette.TEXT_LIGHT, UiTheme.WEIGHT_BOLD)
	for i: int in 3:
		var rect: Rect2 = Rect2(float(i) * (chip_w + 24.0), h * 0.58, chip_w, chip_h)
		_chip(rect, Palette.PANEL_RAISED, Palette.HONEY if i == 0 else Palette.PANEL_EDGE)
		_text("%dx" % (i + 1), rect.get_center(), UiTheme.FONT_BODY, Palette.TEXT_LIGHT, UiTheme.WEIGHT_BOLD, true)


func _spots() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Palette.MEADOW)
	var cell: float = h * 0.62
	MapArt.draw_spot(self, Vector2(w * 0.2, h * 0.5), cell)
	_arrow(Vector2(w * 0.34, h * 0.5), Vector2(w * 0.5, h * 0.5))
	var tower_at: Vector2 = Vector2(w * 0.72, h * 0.5)
	draw_circle(tower_at, cell * 1.35, Color(Palette.ROUTE, 0.16))
	draw_arc(tower_at, cell * 1.35, 0.0, TAU, 64, Color(Palette.ROUTE, 0.9), 4.0, true)
	MapArt.draw_spot(self, tower_at, cell)
	Silhouettes.draw_tower(self, &"sling_post", 1, -1, tower_at, cell)


func _tiers() -> void:
	var w: float = size.x
	var h: float = size.y
	_card_background()
	var cell: float = w * 0.17
	var y: float = h * 0.62
	Silhouettes.draw_tower(self, &"sling_post", 1, -1, Vector2(w * 0.10, y), cell)
	_arrow(Vector2(w * 0.20, y), Vector2(w * 0.30, y), Palette.TEXT_MUTED)
	Silhouettes.draw_tower(self, &"sling_post", 2, -1, Vector2(w * 0.40, y), cell)
	_arrow(Vector2(w * 0.50, y), Vector2(w * 0.58, y), Palette.TEXT_MUTED)
	Silhouettes.draw_tower(self, &"sling_post", 3, 0, Vector2(w * 0.68, y), cell)
	_text("or", Vector2(w * 0.795, y), UiTheme.FONT_BODY, Palette.TEXT_MUTED, UiTheme.WEIGHT_BOLD, true)
	Silhouettes.draw_tower(self, &"sling_post", 3, 1, Vector2(w * 0.90, y), cell)


func _towers() -> void:
	var w: float = size.x
	var h: float = size.y
	_card_background()
	var count: int = Silhouettes.TOWERS.size()
	var cell: float = w / float(count) * 0.95
	for i: int in count:
		var x: float = w * (float(i) + 0.5) / float(count)
		Silhouettes.draw_tower(self, Silhouettes.TOWERS[i], 1, -1, Vector2(x, h * 0.58), cell)
		_caption(i, Vector2(x, h * 0.92), w / float(count))


func _creatures() -> void:
	var w: float = size.x
	var h: float = size.y
	_card_background()
	var ids: Array[StringName] = Silhouettes.CREATURES
	var per_row: int = 6
	for i: int in ids.size():
		@warning_ignore("integer_division")
		var row: int = i / per_row
		var count: int = mini(per_row, ids.size() - row * per_row)
		var column: int = i - row * per_row
		var cell: float = w / float(per_row)
		var x: float = w * 0.5 + (float(column) - float(count - 1) * 0.5) * cell
		var y: float = h * (0.28 + 0.46 * float(row))
		Silhouettes.draw_enemy(self, ids[i], Vector2(x, y), Silhouettes.enemy_size(ids[i], cell * 1.0), 1)
		_caption(i, Vector2(x, y + cell * 0.34), cell)


func _gates() -> void:
	var cell: float = size.x / 7.0
	MapArt.draw_ground(self, GATES_GRID, cell)
	MapArt.draw_gate(self, GATES_GRID, Vector2i(1, 3), cell, MapArt.Gate.CLOSED)
	MapArt.draw_gate(self, GATES_GRID, Vector2i(5, 3), cell, MapArt.Gate.SOCKET)
	MapArt.draw_route(self, MapArt.route_points(GATES_ROUTE, cell), cell, MapArt.Route.WALK)
	_walker(&"scamp", Vector2(3.5, 0.55), cell, 1)


func _signals() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Palette.MEADOW)
	var cell: float = h * 0.2
	var styles: Array[MapArt.Route] = [MapArt.Route.WALK, MapArt.Route.BREAK, MapArt.Route.FLY]
	var names: PackedStringArray = ["Walkers", "Gate breakers", "Flyers"]
	for i: int in 3:
		var y: float = h * (0.12 + 0.18 * float(i))
		_chip(Rect2(w * 0.03, y - cell * 0.5, w * 0.36, cell), Palette.PANEL, Palette.PANEL_EDGE)
		_text(names[i], Vector2(w * 0.03 + 24.0, y), UiTheme.FONT_SMALL, Palette.TEXT_LIGHT, UiTheme.WEIGHT_BOLD)
		var points: PackedVector2Array = PackedVector2Array([Vector2(w * 0.43, y), Vector2(w * 0.95, y)])
		MapArt.draw_route(self, points, cell * 0.8, styles[i])
	var gate_y: float = h * 0.80
	var gate_cell: float = h * 0.24
	var gates: Array[MapArt.Gate] = [MapArt.Gate.REFUSED, MapArt.Gate.BROKEN]
	var gate_names: PackedStringArray = ["Refused", "Broken"]
	for i: int in 2:
		var x: float = w * (0.10 + 0.47 * float(i))
		MapArt.draw_gate_at(self, Vector2(x, gate_y), gate_cell, false, gates[i])
		_chip(Rect2(x + gate_cell * 0.6, gate_y - cell * 0.5, w * 0.28, cell), Palette.PANEL, Palette.PANEL_EDGE)
		_text(gate_names[i], Vector2(x + gate_cell * 0.6 + 24.0, gate_y), UiTheme.FONT_SMALL, Palette.TEXT_LIGHT, UiTheme.WEIGHT_BOLD)


func _stars() -> void:
	var w: float = size.x
	var h: float = size.y
	_card_background()
	var dim: Color = Color(Palette.TEXT_MUTED, 0.5)
	for i: int in 3:
		var flat: Color = Silhouettes.NO_FLAT if i < 2 else dim
		Silhouettes.draw_glyph(self, &"star", Vector2(w * (0.30 + 0.20 * float(i)), h * 0.5), h * 0.72, flat)


# Pieces.

func _walker(id: StringName, at_cell: Vector2, cell: float, frame: int) -> void:
	Silhouettes.draw_enemy(self, id, at_cell * cell, Silhouettes.enemy_size(id, cell), frame)


func _card_background() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.CARD
	box.set_corner_radius_all(UiTheme.RADIUS)
	box.set_border_width_all(3)
	box.border_color = Palette.INK_LINE
	draw_style_box(box, Rect2(Vector2.ZERO, size))


func _chip(rect: Rect2, fill: Color, edge: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	draw_style_box(box, rect)


func _arrow(from: Vector2, to: Vector2, color: Color = Palette.ROUTE) -> void:
	draw_line(from, to - Vector2(10.0, 0.0), color, 6.0, true)
	draw_colored_polygon(PackedVector2Array([to, to - Vector2(26.0, 16.0), to - Vector2(26.0, -16.0)]), color)


func _caption(index: int, at: Vector2, width: float) -> void:
	if index >= captions.size() or captions[index].is_empty():
		return
	var font: Font = UiTheme.font(UiTheme.WEIGHT_BOLD)
	var size_px: int = 30
	var text_w: float = font.get_string_size(captions[index], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	if text_w > width * 1.05:
		size_px = int(float(size_px) * width * 1.05 / text_w)
	draw_string(font, at + Vector2(-width * 0.5, 0.0), captions[index], HORIZONTAL_ALIGNMENT_CENTER, width, size_px, Palette.TEXT_DARK)


## Draws text with its vertical middle (or its center, when `centered`) at `at`.
func _text(text: String, at: Vector2, font_size: int, color: Color, weight: int, centered: bool = false) -> void:
	var font: Font = UiTheme.font(weight)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x: float = at.x - width * 0.5 if centered else at.x
	var y: float = at.y + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
