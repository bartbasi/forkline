# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Map drawing helpers: route lines follow the road cells with the same round
## turns as the roads, and gates know which way their road runs.

const CELL: float = 128.0
const GRID: PackedStringArray = [
	"...1...",
	".o.#.o.",
	".#####.",
	".#.o.#.",
	"oG...#o",
	".#.o.#.",
	".#####.",
	"...B...",
]


func test_route_points_start_and_end_at_cell_centers() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(5, 3)]
	var pts: PackedVector2Array = MapArt.route_points(cells, CELL)
	assert_eq(pts[0], Vector2(3.5, 0.5) * CELL)
	assert_eq(pts[pts.size() - 1], Vector2(5.5, 3.5) * CELL)


func test_route_points_stay_on_the_road() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	var pts: PackedVector2Array = MapArt.route_points(cells, CELL)
	for p: Vector2 in pts:
		var cell: Vector2i = Vector2i(floori(p.x / CELL), floori(p.y / CELL))
		var on_road: bool = cells.has(cell)
		# A point on a cell edge belongs to both neighbors.
		if not on_road:
			for c: Vector2i in cells:
				if Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).grow(0.01).has_point(p):
					on_road = true
		assert_true(on_road, "route point %s is on a road cell" % p)


func test_turns_are_round() -> void:
	# A turn at (3, 2): from down to right. The path never cuts closer to the
	# inner corner than the road's own quarter circle of half a cell.
	var cells: Array[Vector2i] = [Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2)]
	var pts: PackedVector2Array = MapArt.route_points(cells, CELL)
	assert_true(pts.size() > 4, "the turn adds arc points")
	var corner: Vector2 = Vector2(4.0, 2.0) * CELL
	for i: int in range(1, pts.size() - 1):
		assert_near(pts[i].distance_to(corner), CELL * 0.5, 0.5, "arc point %d" % i)


func test_gates_know_their_road() -> void:
	assert_true(MapArt.road_runs_vertically(GRID, Vector2i(1, 4)), "socket on a road running down")
	var across: PackedStringArray = ["...", "#G#", "..."]
	assert_false(MapArt.road_runs_vertically(across, Vector2i(1, 1)), "socket on a road running across")


func test_gate_looks_cover_the_rules() -> void:
	# RULES.md 9.7: open socket, closed, broken (crack) and refused (crossed
	# out); plus fixed gates from twists.
	assert_eq(MapArt.Gate.size(), 5)
	assert_eq(MapArt.Route.size(), 3, "solid walkers, dashed breakers, dotted flyers")
