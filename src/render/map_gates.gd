# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapGates
extends Node2D
## Gates on their sockets: closed, fixed, broken, the open socket ring, and the crossed
## out refused gate. Each look is a region of the MapAtlas sheet, so a gate is one batched
## draw, not the hundred lines it takes to draw one. Redrawn only when the list changes.
## Internal to src/render/.

const CELL: float = 128.0

var grid: PackedStringArray = PackedStringArray()
var atlas: MapAtlas
var cells: Array[Vector2i] = []
var looks: Array[int] = []
var redraws: int = 0


## Sets the list. Returns true when it changed and a redraw was queued.
func set_gates(new_cells: Array[Vector2i], new_looks: Array[int]) -> bool:
	if new_cells == cells and new_looks == looks:
		return false
	cells = new_cells.duplicate()
	looks = new_looks.duplicate()
	redraws += 1
	queue_redraw()
	return true


func _draw() -> void:
	if atlas == null:
		return
	var tex: Texture2D = atlas.get_texture()
	for i: int in cells.size():
		var across: bool = MapArt.road_runs_vertically(grid, cells[i])
		var e: MapAtlas.Entry = atlas.entry_for(MapAtlas.gate_key(looks[i], across))
		if e == null:
			continue
		var c: Vector2 = (Vector2(cells[i]) + Vector2(0.5, 0.5)) * CELL
		draw_texture_rect_region(tex, Rect2(c - e.anchor, e.tile), e.rect)


## The sheet was laid out again: the regions moved, so draw again.
func refresh() -> void:
	queue_redraw()
