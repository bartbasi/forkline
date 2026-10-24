# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapShots
extends Node2D
## Drawn projectiles and the short one-shot marks (hit flashes, pop rings, firework bursts,
## heal pluses, coin glints, speed lines, pulses), in one overlay redrawn every frame while
## something is flying (docs/ARCHITECTURE.md 9.3). The sim has no shots: a hit lands the
## tick a tower fires, and these are only the picture. They fly fast so they arrive at about
## the same time. Every mark has a shape of its own, so none of them is only a color.
## Internal to src/render/.

const CELL: float = 128.0
const MAX_SHOTS: int = 150
const MAX_FLASHES: int = 90
const FLASH_SECONDS: float = 0.14
const RING_SECONDS: float = 0.28

## The pictures of the shots. The Longbow Loft fires ARROW (its Triple Bow fires three at three
## targets) or GIANT_ARROW; the Firework Tower fires ROCKET with a small burst, BLOOM with a
## wide burst, or one heavy SKYROCKET.
enum Look { PEBBLE, STONE, PUMPKIN, JAM, ARROW, GIANT_ARROW, ROCKET, BLOOM, SKYROCKET }
## The short marks, in the order of their lifetimes below.
enum Fx { HIT, RING, BURST, PLUS, COIN, WHOOSH, PULSE }
## PULSE colors: a heal ring, a release ring, a gate ring.
enum Hue { HEAL, RELEASE, GATE }

## Per look: speed in cells a second, the longest flight in seconds, the arc height in cells.
const SPEED: Array[float] = [22.0, 18.0, 15.0, 15.0, 34.0, 30.0, 20.0, 20.0, 24.0]
const LONGEST: Array[float] = [0.16, 0.18, 0.24, 0.24, 0.14, 0.16, 0.22, 0.22, 0.2]
const ARC: Array[float] = [0.08, 0.1, 0.6, 0.6, 0.0, 0.0, 0.1, 0.15, 0.05]
## Per Fx: how long it lasts, in seconds.
const LIFE: Array[float] = [0.14, 0.28, 0.45, 0.6, 0.55, 0.35, 0.45]
const BURST_COLORS: Array[Color] = [Palette.HONEY, Palette.ROOF_CLAY, Palette.SPARKLE, Palette.SPARKLE_LILAC]
const HUES: Array[Color] = [Palette.HP_FILL, Palette.SPARKLE_LILAC, Palette.SPARKLE]


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
	var kind: int = 0
	var at: Vector2 = Vector2.ZERO
	var t0: float = 0.0
	var life: float = 0.14
	## HIT: a size multiplier. BURST, PULSE: the radius in pixels. COIN: a size multiplier.
	## WHOOSH: the creature's size in pixels.
	var size: float = 1.0
	## BURST: 1 for the wide Star Bloom burst. PULSE: a Hue.
	var hue: int = 0
	## WHOOSH: 1.0 when the creature faces right, -1.0 when it faces left.
	var dir: float = 1.0


var shots: Array[Shot] = []
var flashes: Array[Flash] = []
var now: float = 0.0
## For tests: how many shots of each look were launched, and how many marks of each Fx.
var launched: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
var marked: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var _drawn_last: bool = false


## Which look a tower's shot has. Bells and Bakeries never fire.
static func look_for(tower: StringName, spec: int) -> int:
	match tower:
		&"sling_post":
			return Look.STONE if spec == 1 else Look.PEBBLE
		&"pumpkin_catapult":
			return Look.JAM if spec == 1 else Look.PUMPKIN
		&"longbow_loft":
			return Look.GIANT_ARROW if spec == 0 else Look.ARROW
		&"firework_tower":
			if spec == 0:
				return Look.BLOOM
			return Look.SKYROCKET if spec == 1 else Look.ROCKET
	return Look.PEBBLE


## Where a tower's shot leaves from, in map pixels. A tower stands higher on each tier (one stone
## step, 0.08 of a cell), so its top moves up. A Triple Bow (spec 1) sends shot `index` from its own
## bow: left, middle (a little higher), right.
static func muzzle(tower: StringName, cell: Vector2i, tier: int = 3, spec: int = -1, index: int = 0) -> Vector2:
	var at_full: Vector2 = _muzzle_full(tower, cell, tier, spec, index)
	# Towers are drawn at MapAtlas.TOWER_SCALE about their ground line, so the muzzle moves with them.
	var ground: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5 + Silhouettes.TOWER_GROUND)) * CELL
	return ground + (at_full - ground) * MapAtlas.TOWER_SCALE


static func _muzzle_full(tower: StringName, cell: Vector2i, tier: int, spec: int, index: int) -> Vector2:
	var c: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var lift: float = 0.08 * float(clampi(tier, 1, 3) - 1)
	match tower:
		&"pumpkin_catapult":
			return c + Vector2(0.14, -0.42 - lift) * CELL
		&"longbow_loft":
			var x: float = 0.0
			var rise: float = 0.0
			if spec == 1 and tier == 3:
				x = (float(index % 3) - 1.0) * 0.3
				rise = 0.06 if index % 3 == 1 else 0.0
			return c + Vector2(x, -0.56 - lift - rise) * CELL
		&"firework_tower":
			return c + Vector2(0.0, -0.58 - lift) * CELL
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
	launched[look] += 1
	_wake()
	return s.t1


## A bubble pop ring.
func add_ring(at: Vector2, at_time: float) -> void:
	_add_flash(Fx.RING, at, at_time, 1.0, 0, 1.0)


## A firework burst of `radius` pixels (the tower's splash). `wide` is the Star Bloom's.
func add_burst(at: Vector2, at_time: float, radius: float, wide: bool) -> void:
	_add_flash(Fx.BURST, at, at_time, radius, 1 if wide else 0, 1.0)


## A "+" that rises from a creature that was healed.
func add_plus(at: Vector2, at_time: float) -> void:
	_add_flash(Fx.PLUS, at, at_time, 1.0, 0, 1.0)


## A small coin that rises and twinkles. `scale` 1.0 is the glint of one creature.
func add_coin(at: Vector2, at_time: float, scale: float = 1.0) -> void:
	_add_flash(Fx.COIN, at, at_time, scale, 0, 1.0)


## Speed lines trailing a creature of `size` pixels that just got faster.
func add_whoosh(at: Vector2, at_time: float, size: float, facing_left: bool) -> void:
	_add_flash(Fx.WHOOSH, at, at_time, size, 0, -1.0 if facing_left else 1.0)


## A ring that spreads to `radius` pixels.
func add_pulse(at: Vector2, at_time: float, radius: float, hue: Hue) -> void:
	_add_flash(Fx.PULSE, at, at_time, radius, hue, 1.0)


## A hit flash. `big` makes it larger (the Giant Bow, the Skyrocket).
func add_hit(at: Vector2, at_time: float, big: float = 1.0) -> void:
	_add_flash(Fx.HIT, at, at_time, big, 0, 1.0)


## Moves the clock on, ends the shots that arrived and starts their hit flashes.
func advance(time_now: float) -> void:
	now = time_now
	var i: int = 0
	while i < shots.size():
		var s: Shot = shots[i]
		if now >= s.t1:
			_add_flash(Fx.HIT, s.to, s.t1, 1.8 if (s.look == Look.GIANT_ARROW or s.look == Look.SKYROCKET) else 1.0, 0, 1.0)
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


func _add_flash(kind: int, at: Vector2, t0: float, size: float, hue: int, dir: float) -> void:
	if flashes.size() >= MAX_FLASHES:
		flashes.remove_at(0)
	var f: Flash = Flash.new()
	f.kind = kind
	f.at = at
	f.t0 = t0
	f.life = LIFE[kind]
	f.size = size
	f.hue = hue
	f.dir = dir
	flashes.append(f)
	marked[kind] += 1
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
		match f.kind:
			Fx.HIT:
				_draw_hit(f, k)
			Fx.RING:
				draw_arc(f.at, CELL * (0.12 + 0.3 * k), 0.0, TAU, 24, Color(Palette.BUBBLE, 1.0 - k), CELL * 0.04, true)
				draw_arc(f.at, CELL * (0.08 + 0.22 * k), 0.0, TAU, 20, Color(Palette.INK_LINE, 0.6 * (1.0 - k)), CELL * 0.02, true)
			Fx.BURST:
				_draw_burst(f, k)
			Fx.PLUS:
				_draw_plus(f, k)
			Fx.COIN:
				_draw_coin(f, k)
			Fx.WHOOSH:
				_draw_whoosh(f, k)
			Fx.PULSE:
				_draw_pulse(f, k)


func _draw_hit(f: Flash, k: float) -> void:
	var r0: float = CELL * (0.05 + 0.05 * k) * f.size
	var r1: float = CELL * (0.12 + 0.1 * k) * f.size
	for j: int in 4:
		var a: float = TAU * float(j) / 4.0 + PI / 4.0
		var d: Vector2 = Vector2.from_angle(a)
		draw_line(f.at + d * r0, f.at + d * r1, Color(Palette.SPARKLE, 1.0 - k), CELL * 0.035 * minf(f.size, 1.5), true)


## Spokes that reach the splash radius at the end, with a bead on each tip and a faint ring. The
## Star Bloom has more spokes and a second ring.
func _draw_burst(f: Flash, k: float) -> void:
	var fade: float = 1.0 - k * k
	var reach: float = f.size * (0.35 + 0.65 * (1.0 - (1.0 - k) * (1.0 - k)))
	var spokes: int = 12 if f.hue == 1 else 8
	for j: int in spokes:
		var d: Vector2 = Vector2.from_angle(TAU * float(j) / float(spokes) + 0.2)
		var col: Color = BURST_COLORS[j % BURST_COLORS.size()]
		var inner: float = reach * (0.35 + 0.35 * k)
		draw_line(f.at + d * inner, f.at + d * reach, Color(Palette.INK_LINE, 0.7 * fade), CELL * 0.07, true)
		draw_line(f.at + d * inner, f.at + d * reach, Color(col, fade), CELL * 0.04, true)
		draw_circle(f.at + d * reach, CELL * 0.045, Color(Palette.INK_LINE, 0.7 * fade))
		draw_circle(f.at + d * reach, CELL * 0.03, Color(col, fade))
	draw_arc(f.at, reach, 0.0, TAU, 32, Color(Palette.SPARKLE, 0.5 * fade), CELL * 0.02, true)
	if f.hue == 1:
		draw_arc(f.at, reach * 0.55, 0.0, TAU, 24, Color(Palette.HONEY, 0.5 * fade), CELL * 0.02, true)


func _draw_plus(f: Flash, k: float) -> void:
	var p: Vector2 = f.at + Vector2(0.0, -CELL * (0.28 + 0.3 * k))
	var a: float = 1.0 if k < 0.5 else 1.0 - (k - 0.5) * 2.0
	var arm: float = CELL * 0.09 * (0.7 + 0.5 * minf(k * 4.0, 1.0))
	draw_line(p + Vector2(-arm, 0.0), p + Vector2(arm, 0.0), Color(Palette.INK_LINE, a), CELL * 0.085, true)
	draw_line(p + Vector2(0.0, -arm), p + Vector2(0.0, arm), Color(Palette.INK_LINE, a), CELL * 0.085, true)
	draw_line(p + Vector2(-arm, 0.0), p + Vector2(arm, 0.0), Color(Palette.HP_FILL, a), CELL * 0.05, true)
	draw_line(p + Vector2(0.0, -arm), p + Vector2(0.0, arm), Color(Palette.HP_FILL, a), CELL * 0.05, true)


## A small coin that rises, with a four point twinkle at the start. It is round with a mark in
## the middle, so it reads without its color.
func _draw_coin(f: Flash, k: float) -> void:
	var rise: float = 1.0 - (1.0 - k) * (1.0 - k)
	var p: Vector2 = f.at + Vector2(0.0, -CELL * (0.12 + 0.34 * rise * f.size))
	var a: float = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	var r: float = CELL * 0.07 * f.size
	draw_circle(p, r * 1.2, Color(Palette.INK_LINE, a))
	draw_circle(p, r, Color(Palette.COIN, a))
	draw_circle(p, r * 0.45, Color(Palette.ROOF_CLAY, a))
	if k < 0.45:
		var tw: float = sin(PI * k / 0.45)
		var d: float = r * (1.6 + 0.8 * tw)
		var up: Vector2 = p + Vector2(r * 0.9, -r * 0.9)
		draw_line(up + Vector2(-d * 0.5, 0.0), up + Vector2(d * 0.5, 0.0), Color(Palette.SPARKLE, a), CELL * 0.025, true)
		draw_line(up + Vector2(0.0, -d * 0.5), up + Vector2(0.0, d * 0.5), Color(Palette.SPARKLE, a), CELL * 0.025, true)


## Three speed lines behind the creature.
func _draw_whoosh(f: Flash, k: float) -> void:
	var a: float = 1.0 - k
	var s: float = f.size
	for j: int in 3:
		var y: float = (float(j) - 1.0) * 0.2 * s
		var start: Vector2 = f.at + Vector2(-f.dir * (0.4 + 0.2 * k) * s, y)
		var end: Vector2 = start + Vector2(-f.dir * s * (0.35 + 0.25 * float(1 - absi(j - 1))), 0.0)
		draw_line(start, end, Color(Palette.INK_LINE, 0.7 * a), CELL * 0.07, true)
		draw_line(start, end, Color(Palette.SPARKLE, a), CELL * 0.04, true)


func _draw_pulse(f: Flash, k: float) -> void:
	var e: float = 1.0 - (1.0 - k) * (1.0 - k)
	var r: float = f.size * (0.25 + 0.75 * e)
	var a: float = 1.0 - k
	draw_arc(f.at, r, 0.0, TAU, 40, Color(Palette.INK_LINE, 0.6 * a), CELL * 0.07, true)
	draw_arc(f.at, r, 0.0, TAU, 40, Color(HUES[f.hue], a), CELL * 0.04, true)


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
			_arrow(p, dir, 1.0)
		Look.GIANT_ARROW:
			_arrow(p, dir, 2.0)
		Look.SKYROCKET:
			_rocket(p, dir, u, 1.9, Palette.ROOF_CLAY, 3)
		Look.BLOOM:
			_rocket(p, dir, u, 1.3, Palette.HONEY, 2)
		_:
			_rocket(p, dir, u, 1.0, Palette.ROOF_CLAY, 2)


## An arrow whose head is at `p`. The Giant Bow's is twice as long and thick, with a bigger head.
func _arrow(p: Vector2, dir: Vector2, k: float) -> void:
	var tail: Vector2 = p - dir * CELL * 0.4 * k
	var side: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(tail, p, Palette.INK_LINE, CELL * 0.07 * k, true)
	draw_line(tail, p, Palette.WOOD, CELL * 0.035 * k, true)
	var tip: PackedVector2Array = PackedVector2Array([p + dir * CELL * 0.1 * k, p + side * CELL * 0.05 * k, p - side * CELL * 0.05 * k])
	draw_colored_polygon(tip, Palette.IRON)
	draw_line(tail, tail + (side - dir) * CELL * 0.08 * k, Palette.BONE, CELL * 0.03 * k, true)
	draw_line(tail, tail + (-side - dir) * CELL * 0.08 * k, Palette.BONE, CELL * 0.03 * k, true)


## A rocket whose head is at `p`, `big` times the normal size, with `trail` sparks behind it.
func _rocket(p: Vector2, dir: Vector2, u: float, big: float, body: Color, trail: int) -> void:
	var tail: Vector2 = p - dir * CELL * 0.16 * big
	draw_circle(tail - dir * CELL * 0.05, CELL * 0.07 * big, Color(Palette.GLOW, 0.5))
	draw_line(tail, p, Palette.INK_LINE, CELL * 0.075 * big, true)
	draw_line(tail, p, body, CELL * 0.04 * big, true)
	draw_circle(p, CELL * 0.03 * big, Palette.LANTERN_CORE)
	for j: int in trail:
		var back: Vector2 = p - dir * CELL * (0.28 + 0.12 * float(j)) * big
		draw_circle(back, CELL * 0.02 * (1.0 - u * 0.3), Color(Palette.SPARKLE, 0.8 - 0.25 * float(j)))
