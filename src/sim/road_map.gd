# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RoadMap
extends RefCounted
## Routing on a level's road graph (docs/ARCHITECTURE.md 4, RULES 7.3 and 7.4).
## Distances are steps to the base per cell, indexed row * 7 + column.

## The tie break order: south, west, east, north (RULES 7.3).
const STEPS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]

var rows: int = 0
var base: Vector2i = Vector2i(-1, -1)
var entrances: Array[Vector2i] = []
var _road: PackedByteArray = PackedByteArray()        # 1 for a road cell


func _init(level: LevelData) -> void:
	rows = level.rows
	base = level.base
	entrances = level.entrances.duplicate()
	_road.resize(rows * Sim.MAP_COLUMNS)
	for r: int in rows:
		for c: int in Sim.MAP_COLUMNS:
			_road[r * Sim.MAP_COLUMNS + c] = 1 if level.is_road(Vector2i(c, r)) else 0


func size() -> int:
	return rows * Sim.MAP_COLUMNS


func index(cell: Vector2i) -> int:
	return cell.y * Sim.MAP_COLUMNS + cell.x


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Sim.MAP_COLUMNS and cell.y >= 0 and cell.y < rows


func is_road(cell: Vector2i) -> bool:
	return inside(cell) and _road[index(cell)] == 1


## Steps to the base per cell over open road cells; -1 when cut off or not road.
## One breadth first search from the base (docs/ARCHITECTURE.md 4.3).
func distances(closed: Array[Vector2i]) -> PackedInt32Array:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(size())
	dist.fill(-1)
	if not is_road(base) or closed.has(base):
		return dist
	var shut: PackedByteArray = PackedByteArray()
	shut.resize(size())
	for cell: Vector2i in closed:
		if inside(cell):
			shut[index(cell)] = 1
	var queue: Array[Vector2i] = [base]
	dist[index(base)] = 0
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var next_dist: int = dist[index(cell)] + 1
		for step: Vector2i in STEPS:
			var near: Vector2i = cell + step
			if not is_road(near):
				continue
			var i: int = index(near)
			if shut[i] == 1 or dist[i] != -1:
				continue
			dist[i] = next_dist
			queue.append(near)
	return dist


## One step closer to the base: the first open neighbor, in the order south, west,
## east, north, whose distance is exactly one less. The cell itself when there is none.
func next_step(cell: Vector2i, dist: PackedInt32Array) -> Vector2i:
	if not inside(cell):
		return cell
	var here: int = dist[index(cell)]
	if here <= 0:
		return cell
	for step: Vector2i in STEPS:
		var near: Vector2i = cell + step
		if inside(near) and dist[index(near)] == here - 1:
			return near
	return cell


## From a cell to the base, both included; empty when cut off.
func route(from: Vector2i, dist: PackedInt32Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not inside(from) or dist[index(from)] < 0:
		return path
	var cell: Vector2i = from
	path.append(cell)
	while dist[index(cell)] > 0:
		cell = next_step(cell, dist)
		path.append(cell)
	return path


## True when any entrance has no open route to the base.
func seals(closed: Array[Vector2i]) -> bool:
	var dist: PackedInt32Array = distances(closed)
	for entrance: Vector2i in entrances:
		if dist[index(entrance)] < 0:
			return true
	return false
