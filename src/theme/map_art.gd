# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapArt
extends RefCounted
## Draws the map on the 7 column grid (contract 2.2): meadow, roads, build
## spots, gate sockets and gates, the entrances and the base, and route lines.
##
## Everything is drawn in the map's local space: cell (column, row) covers
## [column * cell, (column + 1) * cell] by [row * cell, (row + 1) * cell]. The
## grid is the level file's rows, one character per cell (`.` ground, `#` road,
## `G` road with a socket, `o` build spot, `1` to `4` entrance, `B` base).
##
## Roads are sandy bands through the cell centers. A cell where the road turns
## draws a quarter circle of radius half a cell, so turns are round. Forks and
## the base draw a round plaza. route_points() follows the same curves.

enum Gate { SOCKET, CLOSED, FIXED, BROKEN, REFUSED }
enum Route { WALK, BREAK, FLY }

## Road band width and its border, as fractions of a cell.
const ROAD_WIDTH: float = 0.5
const ROAD_EDGE_WIDTH: float = 0.62
## Build spot pad: center below the cell center, and its half sizes.
const SPOT_DROP: float = 0.2
const SPOT_RX: float = 0.4
const SPOT_RY: float = 0.22
const ENTRANCE_LETTERS: String = "ABCD"

const _DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const _OVERLAP: float = 0.03


# The static map layer.

## Draws everything that does not move: meadow, roads, spots, socket posts,
## scenery, entrance thickets and the base. Gates and route lines are drawn
## separately. With a font, each entrance gets its letter (A to D) on a sign.
static func draw_ground(canvas: CanvasItem, grid: PackedStringArray, cell: float, font: Font = null) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(cell * 0.03, 1.2, 5.0)
	var cols: int = _cols(grid)
	var rows: int = grid.size()
	var size: Vector2 = Vector2(float(cols), float(rows)) * cell
	pen.begin(Vector2.ZERO, 1.0)
	pen.box(0.0, 0.0, size.x, size.y, Palette.MEADOW, false)
	# Lighter patches, then the roads over them.
	for r: int in rows:
		for c: int in cols:
			var h: int = _hash(c, r)
			if h % 5 == 0:
				var p: Vector2 = _center(Vector2i(c, r), cell) + Vector2(float(h % 7) - 3.0, float(h % 5) - 2.0) * cell * 0.08
				pen.detail_poly(InkPen.ellipse_pts(p, cell * (0.55 + float(h % 3) * 0.12), cell * 0.28, 20), Color(Palette.MEADOW_LIGHT, 0.5))
	_draw_roads(pen, grid, cell, ROAD_EDGE_WIDTH, Palette.ROAD_EDGE)
	_draw_roads(pen, grid, cell, ROAD_WIDTH, Palette.ROAD)
	for r: int in rows:
		for c: int in cols:
			var at: Vector2i = Vector2i(c, r)
			var ch: String = _char(grid, at)
			if _is_road(ch) and _is_straight(grid, at):
				_cobbles(pen, at, cell)
			if ch == "G":
				_socket_posts(pen, grid, at, cell)
			elif ch == "o":
				draw_spot(canvas, _center(at, cell), cell)
	# Scenery, back to front.
	for r: int in rows:
		for c: int in cols:
			var at: Vector2i = Vector2i(c, r)
			if _char(grid, at) == ".":
				_scenery(pen, grid, at, cell)
	for r: int in rows:
		for c: int in cols:
			var at: Vector2i = Vector2i(c, r)
			var ch: String = _char(grid, at)
			if ch >= "1" and ch <= "4":
				_thicket(pen, grid, at, cell)
				if font != null:
					_entrance_sign(canvas, pen, grid, at, cell, font, ENTRANCE_LETTERS[ch.to_int() - 1])
			elif ch == "B":
				draw_base(canvas, _center(at, cell), cell)


## An empty build spot: a round stone pad.
static func draw_spot(canvas: CanvasItem, center: Vector2, cell: float) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(cell * 0.025, 1.2, 4.0)
	pen.begin(center + Vector2(0.0, SPOT_DROP * cell), cell / 100.0)
	pen.ellipse(Vector2(0, 4), SPOT_RX * 100.0 + 2.0, SPOT_RY * 100.0 + 2.0, Palette.PAD_EDGE, false)
	pen.ellipse(Vector2(0, 0), SPOT_RX * 100.0, SPOT_RY * 100.0, Palette.PAD)
	pen.detail_path(_closed(InkPen.ellipse_pts(Vector2.ZERO, 26.0, 13.0, 24)), 2.0, Color(Palette.PAD_EDGE, 0.7))
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + PI / 4.0
		var p: Vector2 = Vector2(cos(a) * 33.0, sin(a) * 17.0)
		pen.detail(p * 0.8, p * 1.12, 2.0, Color(Palette.PAD_EDGE, 0.7))


## The base: the village hearth hall, standing on the base cell.
static func draw_base(canvas: CanvasItem, center: Vector2, cell: float) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(cell * 0.03, 1.2, 5.0)
	pen.begin(center + Vector2(0.0, 0.40 * cell), cell / 100.0)
	pen.shadow(Vector2(0, -1), 50.0)
	pen.box(22, -78, 32, -50, Palette.STONE)
	pen.box(-44, -40, 44, 0, Palette.PLASTER)
	for x: float in [-30.0, 30.0]:
		pen.detail(Vector2(x, -40), Vector2(x, 0), 2.0, Palette.TIMBER)
	pen.detail(Vector2(-44, -20), Vector2(44, -20), 2.0, Palette.TIMBER)
	pen.window(-40, -34, -32, -24)
	pen.window(32, -34, 40, -24)
	pen.poly(PackedVector2Array([Vector2(-52, -36), Vector2(52, -36), Vector2(36, -66), Vector2(-36, -66)]), Palette.ROOF_CLAY)
	pen.glow(Vector2(0, -12), 30.0, Palette.GLOW, 1.3)
	pen.door(Vector2(0, 0), 11.0, 26.0, Palette.LANTERN)
	pen.detail(Vector2(0, -24), Vector2(0, 0), 1.6, Palette.TIMBER)
	pen.circle(Vector2(0, -50), 10.0, Palette.CARD)
	Silhouettes.draw_glyph(canvas, &"heart", pen.to_canvas(Vector2(0, -49)), cell * 0.14)
	for x: float in [-20.0, 20.0]:
		pen.stroke(Vector2(x, 0), Vector2(x, -18), 2.4, Palette.TIMBER, false)
		pen.lantern(Vector2(x, -22), 3.6)


## A highlight ring on a cell: the selection, a hint, or the free spots while
## a tower card is picked. `pulse` from 0 to 1 brightens it.
static func draw_highlight(canvas: CanvasItem, at: Vector2i, cell: float, pulse: float = 1.0) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.begin(_center(at, cell), cell / 100.0)
	pen.line_px = clampf(cell * 0.03, 1.2, 5.0)
	var ring: PackedVector2Array = _closed(InkPen.ellipse_pts(Vector2(0, 6), 44.0, 40.0, 32))
	pen.path(ring, 5.0, Color(Palette.HONEY, 0.6 + 0.4 * clampf(pulse, 0.0, 1.0)))


# Gates.

## A gate on the socket at `at`, in one of the Gate looks. Each look has its
## own shape: the open socket is a dashed ring, a fixed gate carries a
## padlock, a broken gate hangs open with a crack, a refused one is crossed out.
static func draw_gate(canvas: CanvasItem, grid: PackedStringArray, at: Vector2i, cell: float, look: Gate) -> void:
	draw_gate_at(canvas, _center(at, cell), cell, _road_runs_vertically(grid, at), look)


## A gate centered on `center` for a cell of `cell` pixels. `across` is true
## on a road that runs up and down the screen. With `flat`, one color only.
static func draw_gate_at(canvas: CanvasItem, center: Vector2, cell: float, across: bool, look: Gate, flat: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var pen: InkPen = InkPen.new(canvas, flat)
	pen.line_px = clampf(cell * 0.03, 1.2, 5.0)
	pen.begin(center, cell / 100.0)
	match look:
		Gate.SOCKET:
			_socket_ring(pen)
			_gate_shape(pen, across, 0.3)
		Gate.CLOSED:
			_gate_shape(pen, across, 1.0)
		Gate.FIXED:
			_gate_shape(pen, across, 1.0)
			_padlock(pen, Vector2(0, -6) if across else Vector2(0, -2))
		Gate.BROKEN:
			_broken_gate(pen, across)
		Gate.REFUSED:
			_gate_shape(pen, across, 0.3)
			for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
				pen.stroke(-d * 26.0 + Vector2(0, -8), d * 26.0 + Vector2(0, -8), 7.0, Palette.HEART)


# Route lines.

## Draws a route line through `points` (map local pixels), in one of the
## Route styles: solid for walkers, dashed for gate breakers, dotted for
## flyers. Walker and breaker lines carry arrows. `phase` from 0 to 1 slides
## the dashes and arrows along, for a gentle motion.
static func draw_route(canvas: CanvasItem, points: PackedVector2Array, cell: float, style: Route, phase: float = 0.0) -> void:
	if points.size() < 2:
		return
	var casing: float = cell * 0.11
	var core: float = cell * 0.055
	var lengths: PackedFloat32Array = _cumulative(points)
	var total: float = lengths[lengths.size() - 1]
	match style:
		Route.WALK:
			canvas.draw_polyline(points, Palette.INK_LINE, casing, true)
			canvas.draw_polyline(points, Palette.ROUTE, core, true)
		Route.BREAK:
			var period: float = cell * 0.36
			var d: float = fposmod(phase, 1.0) * period
			while d < total:
				var seg: PackedVector2Array = _slice(points, lengths, d, minf(d + period * 0.55, total))
				canvas.draw_polyline(seg, Palette.INK_LINE, casing, true)
				canvas.draw_polyline(seg, Palette.ROUTE, core, true)
				d += period
		Route.FLY:
			var gap: float = cell * 0.24
			var d: float = fposmod(phase, 1.0) * gap
			while d < total:
				var p: Vector2 = _point_at(points, lengths, d)
				canvas.draw_circle(p, casing * 0.5, Palette.INK_LINE, true, -1.0, true)
				canvas.draw_circle(p, core * 0.62, Palette.ROUTE, true, -1.0, true)
				d += gap
			return
	# Arrows show which way the creatures go.
	var step: float = cell * 1.25
	var a: float = cell * 0.7 + fposmod(phase, 1.0) * step
	while a < total - cell * 0.4:
		var p: Vector2 = _point_at(points, lengths, a)
		var dir: Vector2 = (_point_at(points, lengths, a + 1.0) - p).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var s: float = cell * 0.13
		var chevron: PackedVector2Array = PackedVector2Array([p - dir * s * 0.3 + side * s, p + dir * s * 0.7, p - dir * s * 0.3 - side * s])
		canvas.draw_polyline(chevron, Palette.INK_LINE, casing, true)
		canvas.draw_polyline(chevron, Palette.ROUTE, core, true)
		a += step


## The drawn path for a list of road cells (entrance to base): through the
## cell centers, with the same quarter circle turns as the roads.
static func route_points(cells: Array[Vector2i], cell: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if cells.is_empty():
		return out
	out.append(_center(cells[0], cell))
	for i: int in range(1, cells.size() - 1):
		var d_in: Vector2i = cells[i] - cells[i - 1]
		var d_out: Vector2i = cells[i + 1] - cells[i]
		var c: Vector2 = _center(cells[i], cell)
		if d_in == d_out:
			out.append(c)
			continue
		var from: Vector2 = c - Vector2(d_in) * cell * 0.5
		var to: Vector2 = c + Vector2(d_out) * cell * 0.5
		out.append_array(_quarter_arc(c, from, to, cell, 8))
	out.append(_center(cells[cells.size() - 1], cell))
	return out


## True when the road at `at` runs up and down the screen.
static func road_runs_vertically(grid: PackedStringArray, at: Vector2i) -> bool:
	return _road_runs_vertically(grid, at)


# Roads.

static func _draw_roads(pen: InkPen, grid: PackedStringArray, cell: float, width_frac: float, col: Color) -> void:
	var w: float = width_frac * cell
	for r: int in grid.size():
		for c: int in _cols(grid):
			var at: Vector2i = Vector2i(c, r)
			if not _is_road(_char(grid, at)):
				continue
			var dirs: Array[Vector2i] = _road_dirs(grid, at)
			var center: Vector2 = _center(at, cell)
			var ext: float = 0.5 + _OVERLAP
			if dirs.size() == 2 and dirs[0] == -dirs[1]:
				pen.path(PackedVector2Array([center + Vector2(dirs[0]) * cell * ext, center + Vector2(dirs[1]) * cell * ext]), w, col, false)
			elif dirs.size() == 2:
				var from: Vector2 = center + Vector2(dirs[0]) * cell * 0.5
				var to: Vector2 = center + Vector2(dirs[1]) * cell * 0.5
				var arc: PackedVector2Array = PackedVector2Array([from + Vector2(dirs[0]) * cell * _OVERLAP])
				arc.append_array(_quarter_arc(center, from, to, cell, 12))
				arc.append(to + Vector2(dirs[1]) * cell * _OVERLAP)
				pen.path(arc, w, col, false)
			else:
				for d: Vector2i in dirs:
					var reach: float = ext
					if _is_outward(grid, at, d):
						reach = 1.2
					pen.path(PackedVector2Array([center, center + Vector2(d) * cell * reach]), w, col, false)
				var plaza: float = w * (0.62 if dirs.size() >= 3 else 0.5)
				pen.circle(center, plaza, col, false)


## The directions a road cell connects in: its road neighbors, plus the way
## out of the map for an entrance.
static func _road_dirs(grid: PackedStringArray, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in _DIRS:
		if _is_road(_char(grid, at + d)) or _is_outward(grid, at, d):
			out.append(d)
	return out


## True when `at` is an entrance and `d` points off the map.
static func _is_outward(grid: PackedStringArray, at: Vector2i, d: Vector2i) -> bool:
	var ch: String = _char(grid, at)
	if not (ch >= "1" and ch <= "4"):
		return false
	var n: Vector2i = at + d
	return n.x < 0 or n.y < 0 or n.x >= _cols(grid) or n.y >= grid.size()


static func _is_straight(grid: PackedStringArray, at: Vector2i) -> bool:
	var dirs: Array[Vector2i] = _road_dirs(grid, at)
	return dirs.size() == 2 and dirs[0] == -dirs[1]


static func _road_runs_vertically(grid: PackedStringArray, at: Vector2i) -> bool:
	return _is_road(_char(grid, at + Vector2i(0, -1))) or _is_road(_char(grid, at + Vector2i(0, 1)))


## A quarter circle from `from` to `to` (two edge middles of the cell at
## `center`), around the cell corner between them.
static func _quarter_arc(center: Vector2, from: Vector2, to: Vector2, cell: float, n: int) -> PackedVector2Array:
	var corner: Vector2 = from + to - center
	var a0: float = (from - corner).angle()
	var delta: float = wrapf((to - corner).angle() - a0, -PI, PI)
	return InkPen.arc_pts(corner, cell * 0.5, cell * 0.5, a0, a0 + delta, n)


static func _cobbles(pen: InkPen, at: Vector2i, cell: float) -> void:
	var h: int = _hash(at.x, at.y)
	var c: Vector2 = _center(at, cell)
	for k: int in 3:
		var hk: int = (h >> (k * 4)) & 15
		var off: Vector2 = Vector2(float(hk % 4) - 1.5, float(hk / 4) - 1.5) * cell * 0.08
		pen.detail_poly(InkPen.ellipse_pts(c + off, cell * 0.045, cell * 0.03, 8), Palette.ROAD_DOT)


static func _socket_posts(pen: InkPen, grid: PackedStringArray, at: Vector2i, cell: float) -> void:
	var c: Vector2 = _center(at, cell)
	var across: Vector2 = Vector2(1, 0) if _road_runs_vertically(grid, at) else Vector2(0, 1)
	for s: float in [-1.0, 1.0]:
		pen.circle(c + across * s * cell * 0.33, cell * 0.055, Palette.STONE_DARK)


# Gate shapes. Local units: 100 is one cell, origin at the socket center.

## The gate. `across` is true on a road that runs up and down the screen: the
## gate then faces the viewer. On a road that runs across the screen it is
## seen from the side, with a plank across the road.
static func _gate_shape(pen: InkPen, across: bool, alpha: float) -> void:
	var ghost: bool = alpha < 1.0
	var wood: Color = Color(Palette.PLASTER, alpha) if ghost else Palette.WOOD
	var post: Color = Color(Palette.PLASTER, alpha) if ghost else Palette.TIMBER
	if across:
		if not ghost:
			pen.box(-33, 10, 33, 17, Palette.TIMBER)
		pen.poly(PackedVector2Array([Vector2(-28, -30), Vector2(28, -30), Vector2(28, 6), Vector2(-28, 6)]), wood, not ghost)
		if not ghost:
			for x: float in [-14.0, 0.0, 14.0]:
				pen.detail(Vector2(x, -28), Vector2(x, 4), 2.4, Palette.TIMBER)
			pen.detail(Vector2(-26, 2), Vector2(26, -26), 3.0, Palette.TIMBER)
		pen.stroke(Vector2(-33, 14), Vector2(-33, -38), 6.0, post, not ghost)
		pen.stroke(Vector2(33, 14), Vector2(33, -38), 6.0, post, not ghost)
		if not ghost:
			pen.lantern(Vector2(-33, -44), 5.0)
			pen.lantern(Vector2(33, -44), 5.0)
	else:
		if not ghost:
			pen.box(-4, -33, 4, 33, Palette.TIMBER)
		pen.poly(PackedVector2Array([Vector2(-11, -40), Vector2(11, -46), Vector2(11, 14), Vector2(-11, 20)]), wood, not ghost)
		if not ghost:
			pen.detail(Vector2(0, -40), Vector2(0, 14), 2.4, Palette.TIMBER)
			pen.detail(Vector2(-9, 14), Vector2(9, -40), 3.0, Palette.TIMBER)
		pen.stroke(Vector2(-13, 24), Vector2(-13, -44), 6.0, post, not ghost)
		pen.stroke(Vector2(13, 18), Vector2(13, -50), 6.0, post, not ghost)
		if not ghost:
			pen.lantern(Vector2(-13, -50), 4.5)
			pen.lantern(Vector2(13, -56), 4.5)


static func _socket_ring(pen: InkPen) -> void:
	for i: int in 10:
		var a0: float = TAU * float(i) / 10.0
		pen.path(InkPen.arc_pts(Vector2(0, -4), 36.0, 36.0, a0, a0 + 0.36, 4), 4.0, Palette.ROUTE)


static func _padlock(pen: InkPen, c: Vector2) -> void:
	pen.path(InkPen.arc_pts(c + Vector2(0, -4), 7.0, 8.0, PI, TAU, 8), 3.5, Palette.IRON)
	pen.box(c.x - 10, c.y - 4, c.x + 10, c.y + 11, Palette.IRON)
	pen.detail_circle(c + Vector2(0, 3), 2.4, Palette.LANTERN)


static func _broken_gate(pen: InkPen, across: bool) -> void:
	if across:
		# Two halves swung open, each with a jagged broken edge.
		pen.poly(PackedVector2Array([Vector2(-28, -30), Vector2(-14, -36), Vector2(-9, -22), Vector2(-15, -12), Vector2(-9, 0), Vector2(-28, 6)]), Palette.WOOD)
		pen.poly(PackedVector2Array([Vector2(28, -30), Vector2(14, -36), Vector2(10, -24), Vector2(4, -14), Vector2(10, -2), Vector2(28, 6)]), Palette.WOOD)
		pen.stroke(Vector2(-33, 14), Vector2(-33, -38), 6.0, Palette.TIMBER)
		pen.stroke(Vector2(33, 14), Vector2(33, -38), 6.0, Palette.TIMBER)
		pen.lantern(Vector2(-33, -44), 5.0, 0.4)
		pen.lantern(Vector2(33, -44), 5.0, 0.4)
	else:
		pen.poly(PackedVector2Array([Vector2(-11, -40), Vector2(11, -46), Vector2(4, -26), Vector2(11, -14), Vector2(-4, -6), Vector2(-11, 0)]), Palette.WOOD)
		pen.stroke(Vector2(-13, 24), Vector2(-13, -44), 6.0, Palette.TIMBER)
		pen.stroke(Vector2(13, 18), Vector2(13, -50), 6.0, Palette.TIMBER)
	# The crack mark: a zigzag, so a broken gate never shows by color alone.
	pen.path(PackedVector2Array([Vector2(-2, -44), Vector2(6, -32), Vector2(-4, -22), Vector2(5, -10), Vector2(-1, 2)]), 3.5, Palette.FLOUR)


# Scenery.

static func _scenery(pen: InkPen, grid: PackedStringArray, at: Vector2i, cell: float) -> void:
	var h: int = _hash(at.x, at.y)
	var c: Vector2 = _center(at, cell)
	var near_road: bool = false
	for d: Vector2i in _DIRS:
		if _is_road(_char(grid, at + d)):
			near_road = true
	pen.begin(c, cell / 100.0)
	var kind: int = h % 10
	if not near_road and kind < 3:
		_tree(pen, Vector2(float(h % 9) - 4.0, 28), 0.62 + float(h % 3) * 0.06, kind == 0)
	elif not near_road and kind < 5:
		pen.shadow(Vector2(0, 24), 22.0)
		pen.circle(Vector2(-9, 14), 14.0, Palette.TREE_DARK)
		pen.circle(Vector2(9, 12), 15.0, Palette.TREE)
	else:
		# Flowers and tufts only near roads, so creatures stay easy to see.
		var n: int = 2 if near_road else 4
		var petals: Array[Color] = [Palette.PLASTER, Palette.SPARKLE_LILAC, Palette.HONEY, Palette.HEART]
		for k: int in n:
			var hk: int = (h >> (k * 3)) & 63
			var p: Vector2 = Vector2(float(hk % 8) - 3.5, float(hk / 8) - 3.5) * 9.0
			if k % 2 == 0:
				pen.detail(p, p + Vector2(-4, -7), 2.0, Palette.MEADOW_DARK)
				pen.detail(p, p + Vector2(0, -9), 2.0, Palette.MEADOW_DARK)
				pen.detail(p, p + Vector2(4, -7), 2.0, Palette.MEADOW_DARK)
			else:
				pen.detail_circle(p, 3.2, petals[(h + k) % petals.size()])
				pen.detail_circle(p, 1.3, Palette.LANTERN)


static func _tree(pen: InkPen, foot: Vector2, k: float, pine: bool) -> void:
	pen.shadow(foot, 22.0 * k)
	if pine:
		pen.box(foot.x - 4 * k, foot.y - 12 * k, foot.x + 4 * k, foot.y, Palette.TIMBER)
		pen.poly(PackedVector2Array([foot + Vector2(-24, -10) * k, foot + Vector2(24, -10) * k, foot + Vector2(0, -46) * k]), Palette.TREE_DARK)
		pen.poly(PackedVector2Array([foot + Vector2(-18, -34) * k, foot + Vector2(18, -34) * k, foot + Vector2(0, -72) * k]), Palette.TREE)
	else:
		pen.box(foot.x - 5 * k, foot.y - 26 * k, foot.x + 5 * k, foot.y, Palette.TIMBER)
		pen.circle(foot + Vector2(-13, -36) * k, 17.0 * k, Palette.TREE_DARK)
		pen.circle(foot + Vector2(13, -38) * k, 17.0 * k, Palette.TREE_DARK)
		pen.circle(foot + Vector2(0, -52) * k, 20.0 * k, Palette.TREE)


## The dark thicket the night creatures come out of, just outside the map
## edge at an entrance.
static func _thicket(pen: InkPen, grid: PackedStringArray, at: Vector2i, cell: float) -> void:
	var out: Vector2i = Vector2i.ZERO
	for d: Vector2i in _DIRS:
		if _is_outward(grid, at, d):
			out = d
	var c: Vector2 = _center(at, cell) + Vector2(out) * cell * 0.62
	pen.begin(c, cell / 100.0)
	var side: Vector2 = Vector2(-out.y, out.x)
	for i: int in 7:
		var t: float = float(i) / 6.0 - 0.5
		var p: Vector2 = side * t * 150.0 + Vector2(out) * (absf(t) * 30.0 + 6.0)
		var r: float = 30.0 + float((i * 7) % 3) * 6.0
		pen.circle(p, r, Palette.TREE_DARK if i % 2 == 0 else Palette.HILL_NEAR)
	pen.ellipse(-Vector2(out) * 6.0, 30.0, 22.0, Palette.THICKET, false)
	if not pen.is_flat():
		for k: int in 3:
			var e: Vector2 = side * (float(k) - 1.0) * 22.0 - Vector2(out) * (4.0 + float(k % 2) * 8.0)
			for dx: float in [-4.5, 4.5]:
				pen.glow(e + side * dx, 7.0, Palette.EYE, 0.8)
				pen.detail_poly(InkPen.ellipse_pts(e + side * dx, 2.8, 3.4, 10), Palette.EYE)


static func _entrance_sign(canvas: CanvasItem, pen: InkPen, grid: PackedStringArray, at: Vector2i, cell: float, font: Font, letter: String) -> void:
	var out: Vector2i = Vector2i.ZERO
	for d: Vector2i in _DIRS:
		if _is_outward(grid, at, d):
			out = d
	var side: Vector2 = Vector2(absf(float(out.y)), absf(float(out.x)))
	var c: Vector2 = _center(at, cell) + side * cell * 0.5 - Vector2(out) * cell * 0.05
	pen.begin(c, cell / 100.0)
	pen.stroke(Vector2(0, 2), Vector2(0, 30), 4.0, Palette.TIMBER)
	pen.circle(Vector2.ZERO, 17.0, Palette.CARD)
	var fs: int = int(cell * 0.22)
	var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: Vector2 = c + Vector2(-w * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	canvas.draw_string(font, base, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT_DARK)


# Grid and path helpers.

static func _cols(grid: PackedStringArray) -> int:
	return grid[0].length() if grid.size() > 0 else 0


static func _char(grid: PackedStringArray, at: Vector2i) -> String:
	if at.y < 0 or at.y >= grid.size() or at.x < 0 or at.x >= grid[at.y].length():
		return ""
	return grid[at.y][at.x]


static func _is_road(ch: String) -> bool:
	return ch == "#" or ch == "G" or ch == "B" or (ch >= "1" and ch <= "4" and ch.length() == 1)


static func _center(at: Vector2i, cell: float) -> Vector2:
	return (Vector2(at) + Vector2(0.5, 0.5)) * cell


## A small fixed hash per cell, so scenery is the same on every draw.
static func _hash(c: int, r: int) -> int:
	var h: int = (c * 73856093) ^ (r * 19349663) ^ 0x5bd1
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


static func _cumulative(pts: PackedVector2Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, pts.size()):
		out.append(out[i - 1] + pts[i - 1].distance_to(pts[i]))
	return out


static func _point_at(pts: PackedVector2Array, lengths: PackedFloat32Array, d: float) -> Vector2:
	var total: float = lengths[lengths.size() - 1]
	var dd: float = clampf(d, 0.0, total)
	for i: int in range(1, pts.size()):
		if lengths[i] >= dd:
			var seg: float = lengths[i] - lengths[i - 1]
			var t: float = 0.0 if seg <= 0.0 else (dd - lengths[i - 1]) / seg
			return pts[i - 1].lerp(pts[i], t)
	return pts[pts.size() - 1]


static func _slice(pts: PackedVector2Array, lengths: PackedFloat32Array, d0: float, d1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([_point_at(pts, lengths, d0)])
	for i: int in pts.size():
		if lengths[i] > d0 and lengths[i] < d1:
			out.append(pts[i])
	out.append(_point_at(pts, lengths, d1))
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out
