# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapRoutes
extends Node2D
## Route lines for every entrance (docs/ARCHITECTURE.md 4.8): solid for walkers, dashed with
## a crack on each closed gate for gate breakers, dotted and straight for flyers. The
## points are worked out once when the lines are set. Internal to src/render/.

const CELL: float = 128.0

## One entrance's lines, ready to draw.
class Line:
	extends RefCounted
	var walk: PackedVector2Array = PackedVector2Array()
	var breaker: PackedVector2Array = PackedVector2Array()
	var fly: PackedVector2Array = PackedVector2Array()
	var cracks: PackedVector2Array = PackedVector2Array()

var lines: Array[Line] = []
var phase: float = 0.0


## `routes` are Battle.routes() entries. An empty list hides the lines.
func set_routes(routes: Array[Dictionary], level: LevelData) -> void:
	lines.clear()
	for r: Dictionary in routes:
		var line: Line = Line.new()
		var walk: Array[Vector2i] = _cells(r.get("walk", []))
		var brk: Array[Vector2i] = _cells(r.get("break", []))
		line.walk = MapArt.route_points(walk, CELL)
		line.breaker = MapArt.route_points(brk, CELL)
		for c: Vector2i in _cells(r.get("cracks", [])):
			line.cracks.append((Vector2(c) + Vector2(0.5, 0.5)) * CELL)
		var index: int = int(r.get("entrance", 1)) - 1
		if bool(r.get("fly", false)) and index >= 0 and index < level.entrances.size():
			line.fly = PackedVector2Array([
				(Vector2(level.entrances[index]) + Vector2(0.5, 0.5)) * CELL,
				(Vector2(level.base) + Vector2(0.5, 0.5)) * CELL])
		lines.append(line)
	queue_redraw()


func is_showing() -> bool:
	return not lines.is_empty()


func advance(seconds: float) -> void:
	if lines.is_empty():
		return
	phase = fposmod(phase + seconds * 0.35, 1.0)
	queue_redraw()


func _draw() -> void:
	for line: Line in lines:
		if line.fly.size() >= 2:
			MapArt.draw_route(self, line.fly, CELL, MapArt.Route.FLY, phase)
	for line: Line in lines:
		if line.breaker.size() >= 2:
			MapArt.draw_route(self, line.breaker, CELL, MapArt.Route.BREAK, phase)
		for c: Vector2 in line.cracks:
			var zig: PackedVector2Array = PackedVector2Array([
				c + Vector2(-2, -44) * CELL / 100.0, c + Vector2(6, -32) * CELL / 100.0,
				c + Vector2(-4, -22) * CELL / 100.0, c + Vector2(5, -10) * CELL / 100.0,
				c + Vector2(-1, 2) * CELL / 100.0])
			draw_polyline(zig, Palette.INK_LINE, CELL * 0.1, true)
			draw_polyline(zig, Palette.FLOUR, CELL * 0.05, true)
	for line: Line in lines:
		if line.walk.size() >= 2:
			MapArt.draw_route(self, line.walk, CELL, MapArt.Route.WALK, phase)


static func _cells(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for c: Variant in raw as Array:
			if c is Vector2i:
				out.append(c)
	return out
