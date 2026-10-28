# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## The map feature rules that are level design rules, not load checks (RULES 3.5, 3.6, 14.2;
## docs/ARCHITECTURE.md 14.2, 14.13). Used on campaign levels and on assembled run maps, so a
## run map is checked across the seams between its segments.

## RULES 3.6: a map has at most 6 tunnel tiles, and a tunnel is 1 to 4 tiles long.
const MAX_TUNNEL_TILES: int = 6
const MAX_TUNNEL_RUN: int = 4
## RULES 3.6: tunnels hold at most a quarter of the steps of any entrance's shortest route with no gates.
const TUNNEL_SHARE_DIVISOR: int = 4
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func tunnel_tiles(level: LevelData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: int in level.rows:
		for c: int in Sim.MAP_COLUMNS:
			var cell: Vector2i = Vector2i(c, r)
			if level.feature_at(cell) == LevelData.Feature.TUNNEL:
				out.append(cell)
	return out


## The tunnels of a map: each one the list of its tiles, joined north, south, east or west.
static func tunnels(level: LevelData) -> Array[Array]:
	var tiles: Array[Vector2i] = tunnel_tiles(level)
	var done: Dictionary = {}
	var out: Array[Array] = []
	for start: Vector2i in tiles:
		if done.has(start):
			continue
		var run: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		done[start] = true
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			run.append(cell)
			for side: Vector2i in SIDES:
				var next: Vector2i = cell + side
				if tiles.has(next) and not done.has(next):
					done[next] = true
					todo.append(next)
		run.sort()
		out.append(run)
	return out


## Every way the tunnels of `level` break RULES 3.6, one line each. Empty when they keep every rule.
static func tunnel_problems(level: LevelData) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tiles: Array[Vector2i] = tunnel_tiles(level)
	if tiles.size() > MAX_TUNNEL_TILES:
		out.append("%d tunnel tiles, at most %d" % [tiles.size(), MAX_TUNNEL_TILES])
	for run: Array in tunnels(level):
		var rows: Dictionary = {}
		var columns: Dictionary = {}
		for cell: Vector2i in run:
			rows[cell.y] = true
			columns[cell.x] = true
		if run.size() > MAX_TUNNEL_RUN:
			out.append("the tunnel at %s is %d tiles, at most %d" % [run[0], run.size(), MAX_TUNNEL_RUN])
		if rows.size() > 1 and columns.size() > 1:
			out.append("the tunnel at %s bends" % run[0])
		# Each tile has exactly two road neighbors, on opposite sides, in the line of its tunnel.
		var along_column: bool = columns.size() == 1 and rows.size() > 1
		var along_row: bool = rows.size() == 1 and columns.size() > 1
		for cell: Vector2i in run:
			var up: bool = level.is_road(cell + Vector2i.UP)
			var down: bool = level.is_road(cell + Vector2i.DOWN)
			var left: bool = level.is_road(cell + Vector2i.LEFT)
			var right: bool = level.is_road(cell + Vector2i.RIGHT)
			var vertical: bool = up and down and not left and not right
			var horizontal: bool = left and right and not up and not down
			if not vertical and not horizontal:
				out.append("tunnel tile %s is a fork, a bend or a dead end" % cell)
			elif (along_column and not vertical) or (along_row and not horizontal):
				out.append("tunnel tile %s does not run in the line of its tunnel" % cell)
	for cell: Vector2i in tiles:
		for side: Vector2i in SIDES:
			if level.sockets.has(cell + side):
				out.append("tunnel tile %s is next to the socket %s" % [cell, cell + side])
	if not tiles.is_empty():
		var map: RoadMap = RoadMap.new(level)
		var none: Array[Vector2i] = []
		var dist: PackedInt32Array = map.distances(none)
		for i: int in level.entrances.size():
			var route: Array[Vector2i] = map.route(level.entrances[i], dist)
			var steps: int = route.size() - 1
			var under: int = 0
			for cell: Vector2i in route:
				if tiles.has(cell):
					under += 1
			if under * TUNNEL_SHARE_DIVISOR > steps:
				out.append("entrance %d: %d of %d steps in tunnels, at most a quarter" % [i + 1, under, steps])
	return out


## The feature grid characters a map holds, each once, in reading order.
static func feature_chars(grid: PackedStringArray) -> String:
	var out: String = ""
	for line: String in grid:
		for i: int in line.length():
			var ch: String = line[i]
			if "TX^v<>PQ".contains(ch) and not out.contains(ch):
				out += ch
	return out


## Every placement of up to `left` gates on `sockets`, the empty one included.
static func gate_sets(sockets: Array[Vector2i], left: int, start: int, current: Array, out: Array[Array]) -> void:
	out.append(current.duplicate())
	if left == 0:
		return
	for i: int in range(start, sockets.size()):
		var next: Array = current.duplicate()
		next.append(sockets[i])
		gate_sets(sockets, left - 1, i + 1, next, out)
