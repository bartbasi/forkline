# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapShots
extends Node2D
## Drawn projectiles, hit flashes and bubble pop rings, in one overlay redrawn every
## frame while something is flying (docs/ARCHITECTURE.md 9.3). The sim has no shots: a hit
## lands the tick a tower fires, and these are only the picture. They fly fast so they
## arrive at about the same time. Internal to src/render/.

const CELL: float = 128.0
const MAX_SHOTS: int = 150
const MAX_FLASHES: int = 60
const FLASH_SECONDS: float = 0.14
const RING_SECONDS: float = 0.28

enum Look { PEBBLE, STONE, PUMPKIN, JAM, ARROW, ROCKET, BLOOM }

## Per look: speed in cells a second, the longest flight in seconds, the arc height in cells.
const SPEED: Array[float] = [22.0, 18.0, 15.0, 15.0, 34.0, 20.0, 20.0]
const LONGEST: Array[float] = [0.16, 0.18, 0.24, 0.24, 0.14, 0.22, 0.22]
const ARC: Array[float] = [0.08, 0.1, 0.6, 0.6, 0.0, 0.1, 0.15]


class Shot:
	extends RefCounted
	var look: int = 0
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var t0: float = 0.0
	var t1: float = 0.0
	var target: int = -1


class Flash:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var t0: float = 0.0
	var life: float = 0.14
	var ring: bool = false


var shots: Array[Shot] = []
var flashes: Array[Flash] = []
var now: float = 0.0
var _drawn_last: bool = false


## Which look a tower's shot has. Bells and Bakeries never fire.
static func look_for(tower: StringName, spec: int) -> int:
	match tower:
		&"sling_post":
			return Look.STONE if spec == 1 else Look.PEBBLE
		&"pumpkin_catapult":
			return Look.JAM if spec == 1 else Look.PUMPKIN
		&"longbow_loft":
			return Look.ARROW
		&"firework_tower":
			return Look.BLOOM if spec == 0 else Look.ROCKET
	return Look.PEBBLE


## Where a tower's shot leaves from, in map pixels.
static func muzzle(tower: StringName, cell: Vector2i) -> Vector2:
	var c: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	match tower:
		&"pumpkin_catapult":
			return c + Vector2(0.14, -0.42) * CELL
		&"longbow_loft":
			return c + Vector2(0.0, -0.7) * CELL
	return c + Vector2(0.0, -0.5) * CELL


## Starts a shot and returns the time it arrives.
func launch(look: int, from: Vector2, to: Vector2, target: int, at_time: float) -> float:
	var length_cells: float = from.distance_to(to) / CELL
	var flight: float = clampf(length_cells / SPEED[look], 0.05, LONGEST[look])
	if shots.size() >= MAX_SHOTS:
		shots.remove_at(0)
	var s: Shot = Shot.new()
	s.look = look
	s.from = from
	s.to = to
	s.t0 = at_time
	s.t1 = at_time + flight
	s.target = target
	shots.append(s)
	_wake()
	return s.t1


func add_ring(at: Vector2, at_time: float) -> void:
	_add_flash(at, at_time, true)


## Moves the clock on, ends the shots that arrived and starts their hit flashes.
func advance(time_now: float) -> void:
	now = time_now
	var i: int = 0
	while i < shots.size():
		var s: Shot = shots[i]
		if now >= s.t1:
			_add_flash(s.to, s.t1, false)
			shots.remove_at(i)
		else:
			i += 1
	i = 0
	while i < flashes.size():
		if now - flashes[i].t0 > flashes[i].life:
			flashes.remove_at(i)
		else:
			i += 1
	if not shots.is_empty() or not flashes.is_empty():
		queue_redraw()
		_drawn_last = true
	elif _drawn_last:
		_drawn_last = false
		queue_redraw()


func is_busy() -> bool:
	return not shots.is_empty() or not flashes.is_empty()


func _wake() -> void:
	queue_redraw()
	_drawn_last = true


func _add_flash(at: Vector2, t0: float, ring: bool) -> void:
	if flashes.size() >= MAX_FLASHES:
		flashes.remove_at(0)
	var f: Flash = Flash.new()
	f.at = at
	f.t0 = t0
	f.ring = ring
	f.life = RING_SECONDS if ring else FLASH_SECONDS
	flashes.append(f)
	_wake()


func _point(s: Shot, u: float) -> Vector2:
	var arc: float = ARC[s.look] * CELL * 4.0 * u * (1.0 - u)
	return s.from.lerp(s.to, u) + Vector2(0.0, -arc)


func _draw() -> void:
	for s: Shot in shots:
		var u: float = clampf((now - s.t0) / maxf(s.t1 - s.t0, 0.001), 0.0, 1.0)
		var p: Vector2 = _point(s, u)
		var ahead: Vector2 = _point(s, minf(u + 0.05, 1.0))
		var dir: Vector2 = (ahead - p).normalized() if ahead != p else Vector2.RIGHT
		_draw_shot(s.look, p, dir, u)
	for f: Flash in flashes:
		if now < f.t0:
			continue
		var k: float = clampf((now - f.t0) / f.life, 0.0, 1.0)
		if f.ring:
			draw_arc(f.at, CELL * (0.12 + 0.3 * k), 0.0, TAU, 24, Color(Palette.BUBBLE, 1.0 - k), CELL * 0.04, true)
			draw_arc(f.at, CELL * (0.08 + 0.22 * k), 0.0, TAU, 20, Color(Palette.INK_LINE, 0.6 * (1.0 - k)), CELL * 0.02, true)
		else:
			var r0: float = CELL * (0.05 + 0.05 * k)
			var r1: float = CELL * (0.12 + 0.1 * k)
			for j: int in 4:
				var a: float = TAU * float(j) / 4.0 + PI / 4.0
				var d: Vector2 = Vector2.from_angle(a)
				draw_line(f.at + d * r0, f.at + d * r1, Color(Palette.SPARKLE, 1.0 - k), CELL * 0.035, true)


func _draw_shot(look: int, p: Vector2, dir: Vector2, u: float) -> void:
	var ink: Color = Palette.INK_LINE
	match look:
		Look.PEBBLE:
			draw_circle(p, CELL * 0.055, ink)
			draw_circle(p, CELL * 0.035, Palette.PLASTER)
		Look.STONE:
			draw_circle(p, CELL * 0.085, ink)
			draw_circle(p, CELL * 0.062, Palette.STONE)
			draw_circle(p + Vector2(-0.02, -0.02) * CELL, CELL * 0.02, Palette.PLASTER)
		Look.PUMPKIN:
			draw_circle(p, CELL * 0.12, ink)
			draw_circle(p, CELL * 0.095, Palette.PUMPKIN)
			draw_line(p + Vector2(0.0, -0.09) * CELL, p + Vector2(0.02, -0.14) * CELL, Palette.TREE_DARK, CELL * 0.03, true)
		Look.JAM:
			draw_circle(p, CELL * 0.12, ink)
			draw_circle(p, CELL * 0.095, Palette.JAM)
			draw_circle(p + Vector2(-0.03, -0.03) * CELL, CELL * 0.025, Palette.SPARKLE_LILAC)
		Look.ARROW:
			var tail: Vector2 = p - dir * CELL * 0.4
			var side: Vector2 = Vector2(-dir.y, dir.x)
			draw_line(tail, p, ink, CELL * 0.07, true)
			draw_line(tail, p, Palette.WOOD, CELL * 0.035, true)
			var tip: PackedVector2Array = PackedVector2Array([p + dir * CELL * 0.1, p + side * CELL * 0.05, p - side * CELL * 0.05])
			draw_colored_polygon(tip, Palette.IRON)
			draw_line(tail, tail + (side - dir) * CELL * 0.08, Palette.BONE, CELL * 0.03, true)
			draw_line(tail, tail + (-side - dir) * CELL * 0.08, Palette.BONE, CELL * 0.03, true)
		_:
			var big: float = 1.4 if look == Look.BLOOM else 1.0
			var tail2: Vector2 = p - dir * CELL * 0.16 * big
			draw_circle(tail2 - dir * CELL * 0.05, CELL * 0.07 * big, Color(Palette.GLOW, 0.5))
			draw_line(tail2, p, ink, CELL * 0.075 * big, true)
			draw_line(tail2, p, Palette.ROOF_CLAY, CELL * 0.04 * big, true)
			draw_circle(p, CELL * 0.03 * big, Palette.LANTERN_CORE)
			for j: int in 2:
				var back: Vector2 = p - dir * CELL * (0.28 + 0.12 * float(j)) * big
				draw_circle(back, CELL * 0.02 * (1.0 - u * 0.3), Color(Palette.SPARKLE, 0.8 - 0.3 * float(j)))
