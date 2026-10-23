# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Draws the slice's towers, creatures, gate, village and icons in code.
## Prototype only. Every shape is drawn in a local box (towers about 100 units
## wide, anchored at the bottom center; creatures about 40 units, anchored at
## the feet) and scaled onto the canvas. With `mono` on, every fill and line
## uses one color, which gives the silhouette sheet.

const P: GDScript = preload("res://prototypes/theme/palette.gd")

enum Tower { WATCH, BAKE, MILL, LOOKOUT, ROCKET, LANTERN }
enum Creature { BASIC, FAST, ARMORED, SWARM }

const TOWER_NAMES: PackedStringArray = ["Watch post", "Bakehouse", "Flour mill", "Lookout", "Firework loft", "Lantern cottage"]
const TOWER_SHORT: PackedStringArray = ["Watch", "Bakery", "Mill", "Lookout", "Rockets", "Lantern"]
const TOWER_ROLES: PackedStringArray = ["rapid single target", "splash", "slows", "long range, pierces armor", "anti air", "boosts neighbors"]
const CREATURE_NAMES: PackedStringArray = ["Nightling", "Dasher", "Shellback", "Mites"]
const CREATURE_ROLES: PackedStringArray = ["basic", "fast", "armored", "swarm"]

var ci: CanvasItem
var mono: bool = false
var mono_color: Color = P.INK_LINE
var lw: float = 3.0
var t: float = 0.0
var _base: Transform2D = Transform2D.IDENTITY


# Transform helpers.

func begin(pos: Vector2, scale: float, flip: bool = false) -> void:
	_base = Transform2D(0.0, Vector2(-scale if flip else scale, scale), 0.0, pos)
	ci.draw_set_transform_matrix(_base)


func local_rotate(pivot: Vector2, angle: float) -> void:
	var xf: Transform2D = _base * Transform2D(0.0, pivot) * Transform2D(angle, Vector2.ZERO) * Transform2D(0.0, -pivot)
	ci.draw_set_transform_matrix(xf)


func local_reset() -> void:
	ci.draw_set_transform_matrix(_base)


func end() -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# Primitive helpers.

func fc(c: Color) -> Color:
	return Color(mono_color, c.a) if mono else c


func lc() -> Color:
	return mono_color if mono else P.INK_LINE


func poly(pts: PackedVector2Array, fill: Color, outline: bool = true) -> void:
	ci.draw_colored_polygon(pts, fc(fill))
	if outline:
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, lc(), lw, true)


func circle(c: Vector2, r: float, fill: Color, outline: bool = true) -> void:
	ci.draw_circle(c, r, fc(fill), true, -1.0, true)
	if outline:
		ci.draw_arc(c, r, 0.0, TAU, 28, lc(), lw, true)


func ellipse(c: Vector2, rx: float, ry: float, fill: Color, outline: bool = true) -> void:
	poly(ellipse_pts(c, rx, ry, 24), fill, outline)


func box(x0: float, y0: float, x1: float, y1: float, fill: Color, outline: bool = true) -> void:
	poly(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), fill, outline)


func stroke(a: Vector2, b: Vector2, width: float, col: Color, cased: bool = true) -> void:
	if cased:
		ci.draw_line(a, b, lc(), width + lw * 2.0, true)
	ci.draw_line(a, b, fc(col), width, true)


func detail(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	if not mono:
		ci.draw_line(a, b, col, width, true)


func glow(c: Vector2, r: float, col: Color, strength: float = 1.0) -> void:
	if mono:
		return
	for i: int in 6:
		var k: float = 1.0 - float(i) / 6.0
		ci.draw_circle(c, r * k, Color(col, 0.07 * strength), true, -1.0, true)


static func ellipse_pts(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func arc_pts(c: Vector2, rx: float, ry: float, from: float, to: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in n + 1:
		var a: float = lerpf(from, to, float(i) / float(n))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func lantern(c: Vector2, r: float, bright: float = 1.0) -> void:
	glow(c, r * 5.0, P.GLOW, bright)
	poly(PackedVector2Array([c + Vector2(-r * 0.9, -r * 1.1), c + Vector2(r * 0.9, -r * 1.1), c + Vector2(0.0, -r * 1.9)]), P.TIMBER)
	box(c.x - r * 0.75, c.y - r * 1.1, c.x + r * 0.75, c.y + r * 1.0, P.LANTERN)
	if not mono:
		ci.draw_circle(c, r * 0.45, P.LANTERN_CORE, true, -1.0, true)


func window(x0: float, y0: float, x1: float, y1: float, bright: float = 1.0) -> void:
	glow(Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5), (x1 - x0) * 1.6, P.GLOW, bright * 0.8)
	box(x0, y0, x1, y1, P.LANTERN)
	detail(Vector2((x0 + x1) * 0.5, y0 + 1.5), Vector2((x0 + x1) * 0.5, y1 - 1.5), 1.6, P.TIMBER)
	detail(Vector2(x0 + 1.5, (y0 + y1) * 0.5), Vector2(x1 - 1.5, (y0 + y1) * 0.5), 1.6, P.TIMBER)


func shadow(rx: float) -> void:
	if not mono:
		ci.draw_colored_polygon(ellipse_pts(Vector2(0.0, -1.0), rx, rx * 0.22, 20), Color(0.05, 0.03, 0.1, 0.28))


# Towers. Local box: about 100 wide, anchored at the bottom center.

## Draws one tier 1 tower. `aim` is the angle to its target in radians (0
## points right), `flash` runs 1 to 0 after a shot.
func tower(kind: int, pos: Vector2, size: float, aim: float = -PI / 2.0, flash: float = 0.0) -> void:
	begin(pos, size / 100.0)
	match kind:
		Tower.WATCH:
			_watch(flash)
		Tower.BAKE:
			_bake(flash)
		Tower.MILL:
			_mill(flash)
		Tower.LOOKOUT:
			_lookout(aim, flash)
		Tower.ROCKET:
			_rocket(flash)
		Tower.LANTERN:
			_lantern_cottage(flash)
	end()


func _watch(flash: float) -> void:
	shadow(44.0)
	poly(PackedVector2Array([Vector2(-38, 0), Vector2(-27, 0), Vector2(-15, -76), Vector2(-24, -76)]), P.WOOD)
	poly(PackedVector2Array([Vector2(27, 0), Vector2(38, 0), Vector2(24, -76), Vector2(15, -76)]), P.WOOD)
	stroke(Vector2(-29, -14), Vector2(17, -62), 4.0, P.TIMBER)
	stroke(Vector2(29, -14), Vector2(-17, -62), 4.0, P.TIMBER)
	box(-36, -84, 36, -74, P.WOOD)
	box(-27, -120, 27, -84, P.PLASTER)
	detail(Vector2(-27, -102), Vector2(-14, -102), 3.0, P.TIMBER)
	detail(Vector2(14, -102), Vector2(27, -102), 3.0, P.TIMBER)
	window(-10, -113, 10, -92, 1.0 + flash)
	poly(PackedVector2Array([Vector2(-38, -116), Vector2(38, -116), Vector2(0, -170)]), P.ROOF_CLAY)
	stroke(Vector2(0, -170), Vector2(0, -188), 2.5, P.TIMBER, false)
	poly(PackedVector2Array([Vector2(0, -190), Vector2(22, -183 + sin(t * 5.0) * 2.0), Vector2(0, -176)]), P.HONEY)
	stroke(Vector2(27, -108), Vector2(40, -108), 3.0, P.TIMBER, false)
	lantern(Vector2(40, -94), 6.0, 1.0 + flash)


func _bake(flash: float) -> void:
	shadow(56.0)
	box(18, -98, 36, -46, P.ROOF_CLAY)
	box(14, -104, 40, -96, P.STONE_DARK)
	var dome: PackedVector2Array = arc_pts(Vector2(0, 0), 58.0, 72.0, PI, TAU, 20)
	poly(dome, P.PLASTER_SHADE)
	for row: int in 3:
		var y: float = -18.0 - float(row) * 17.0
		var half: float = 58.0 * sqrt(maxf(0.0, 1.0 - pow(y / 72.0, 2.0)))
		detail(Vector2(-half + 3.0, y), Vector2(half - 3.0, y), 1.5, P.STONE_DARK)
	var mouth: PackedVector2Array = arc_pts(Vector2(0, -16), 19.0, 19.0, PI, TAU, 10)
	mouth.append(Vector2(19, 0))
	mouth.append(Vector2(-19, 0))
	poly(mouth, P.INK_LINE)
	glow(Vector2(0, -10), 34.0, P.GLOW, 1.2 + flash * 1.5)
	if not mono:
		ci.draw_colored_polygon(ellipse_pts(Vector2(0, -7), 13.0, 8.0 + flash * 3.0, 14), P.GLOW)
		ci.draw_colored_polygon(ellipse_pts(Vector2(0, -6), 7.0, 4.0, 10), P.LANTERN_CORE)
	window(-38, -44, -24, -32, 1.0)
	if not mono:
		for i: int in 3:
			var k: float = fmod(t * 0.35 + float(i) / 3.0, 1.0)
			ci.draw_circle(Vector2(27.0 + sin(k * 6.0 + float(i)) * 6.0, -110.0 - k * 46.0), 6.0 + k * 9.0, Color(P.SMOKE, 0.45 * (1.0 - k)), true, -1.0, true)


func _mill(flash: float) -> void:
	shadow(40.0)
	poly(PackedVector2Array([Vector2(-31, 0), Vector2(31, 0), Vector2(21, -92), Vector2(-21, -92)]), P.PLASTER)
	detail(Vector2(-27, -44), Vector2(27, -44), 2.5, P.TIMBER)
	var door: PackedVector2Array = arc_pts(Vector2(0, -14), 9.0, 9.0, PI, TAU, 8)
	door.append(Vector2(9, 0))
	door.append(Vector2(-9, 0))
	poly(door, P.TIMBER)
	window(-7, -70, 7, -56, 1.0)
	poly(PackedVector2Array([Vector2(-27, -90), Vector2(27, -90), Vector2(0, -124)]), P.ROOF_SLATE)
	var hub: Vector2 = Vector2(0, -98)
	var spin: float = t * (1.1 + flash * 2.0)
	for k: int in 4:
		var a: float = spin + float(k) * PI / 2.0
		var along: Vector2 = Vector2(cos(a), sin(a))
		var side: Vector2 = Vector2(-along.y, along.x)
		var cloth: PackedVector2Array = PackedVector2Array([
			hub + along * 14.0 + side * 3.0, hub + along * 76.0 + side * 3.0,
			hub + along * 76.0 + side * 20.0, hub + along * 18.0 + side * 17.0])
		poly(cloth, P.PLASTER_SHADE)
		detail(hub + along * 36.0 + side * 3.0, hub + along * 36.0 + side * 19.0, 1.5, P.WOOD)
		detail(hub + along * 56.0 + side * 3.0, hub + along * 56.0 + side * 20.0, 1.5, P.WOOD)
		stroke(hub, hub + along * 78.0, 3.5, P.WOOD)
	circle(hub, 6.0, P.TIMBER)


func _lookout(aim: float, flash: float) -> void:
	shadow(36.0)
	poly(PackedVector2Array([Vector2(-27, 0), Vector2(27, 0), Vector2(22, -128), Vector2(-22, -128)]), P.STONE)
	for row: int in 5:
		var y: float = -20.0 - float(row) * 22.0
		var off: float = 8.0 if row % 2 == 0 else -6.0
		detail(Vector2(-14 + off, y), Vector2(2 + off, y), 2.0, P.STONE_DARK)
	var door: PackedVector2Array = arc_pts(Vector2(0, -16), 9.0, 9.0, PI, TAU, 8)
	door.append(Vector2(9, 0))
	door.append(Vector2(-9, 0))
	poly(door, P.TIMBER)
	glow(Vector2(0, -92), 22.0, P.GLOW, 1.0)
	box(-4, -104, 4, -80, P.LANTERN)
	box(-31, -142, 31, -126, P.STONE)
	box(-31, -154, -19, -142, P.STONE)
	box(-6, -154, 6, -142, P.STONE)
	box(19, -154, 31, -142, P.STONE)
	# The bow tilts toward its target, at most about 35 degrees.
	var tilt: float = clampf(wrapf(aim + PI / 2.0, -PI, PI), -0.6, 0.6)
	local_rotate(Vector2(0, -160), tilt)
	var pull: float = 6.0 - flash * 6.0
	var bow: PackedVector2Array = PackedVector2Array([Vector2(-60, -156), Vector2(-40, -170), Vector2(0, -178), Vector2(40, -170), Vector2(60, -156)])
	ci.draw_polyline(bow, lc(), 8.0 + lw * 2.0, true)
	ci.draw_polyline(bow, fc(P.WOOD), 8.0, true)
	detail(Vector2(-60, -156), Vector2(0, -164 + pull), 1.5, P.PLASTER)
	detail(Vector2(60, -156), Vector2(0, -164 + pull), 1.5, P.PLASTER)
	box(-5, -168, 5, -150, P.TIMBER)
	if flash < 0.6:
		stroke(Vector2(0, -164 + pull), Vector2(0, -204), 3.0, P.TIMBER)
		poly(PackedVector2Array([Vector2(-6, -202), Vector2(6, -202), Vector2(0, -216)]), P.LANTERN_CORE)
	local_reset()


func _rocket(flash: float) -> void:
	shadow(48.0)
	# Three rockets in a fan; the middle one is away for a moment after a shot.
	var colors: Array[Color] = [P.ROOF_CLAY, P.HONEY, P.ROOF_SLATE]
	for i: int in 3:
		if i == 1 and flash > 0.35:
			continue
		var a: float = (float(i) - 1.0) * 0.5
		local_rotate(Vector2(0, -74), a)
		# Stubby rocket: round nose, wide fins, a glowing fuse.
		poly(PackedVector2Array([Vector2(-9, -100), Vector2(-17, -80), Vector2(-9, -86)]), P.TIMBER)
		poly(PackedVector2Array([Vector2(9, -100), Vector2(17, -80), Vector2(9, -86)]), P.TIMBER)
		box(-8, -128, 8, -86, colors[i])
		poly(PackedVector2Array([Vector2(-8, -128), Vector2(-5, -138), Vector2(0, -150), Vector2(5, -138), Vector2(8, -128)]), P.ROOF_PLUM)
		star(Vector2(0, -108), 5.0, P.PLASTER)
		glow(Vector2(0, -82), 8.0, P.GLOW, 1.0)
		local_reset()
	stroke(Vector2(-24, -66), Vector2(0, -84), 4.0, P.TIMBER)
	stroke(Vector2(24, -66), Vector2(0, -84), 4.0, P.TIMBER)
	box(-40, -58, 40, 0, P.PLASTER)
	detail(Vector2(-40, -30), Vector2(40, -30), 2.5, P.TIMBER)
	box(-10, -28, 10, 0, P.TIMBER)
	window(-32, -50, -19, -37, 1.0 + flash)
	window(19, -50, 32, -37, 1.0 + flash)
	poly(PackedVector2Array([Vector2(-48, -55), Vector2(48, -55), Vector2(43, -70), Vector2(-43, -70)]), P.ROOF_PLUM)


func _lantern_cottage(flash: float) -> void:
	shadow(52.0)
	box(-46, -42, 24, 0, P.PLASTER)
	var door: PackedVector2Array = arc_pts(Vector2(-22, -18), 9.0, 10.0, PI, TAU, 8)
	door.append(Vector2(-13, 0))
	door.append(Vector2(-31, 0))
	poly(door, P.TIMBER)
	window(2, -32, 16, -19, 1.0)
	# A steep turf gable with a dormer: the low cottage under the big crook.
	poly(PackedVector2Array([Vector2(-54, -38), Vector2(32, -38), Vector2(-11, -92)]), P.ROOF_MOSS)
	box(-30, -62, -18, -50, P.PLASTER)
	poly(PackedVector2Array([Vector2(-33, -60), Vector2(-15, -60), Vector2(-24, -70)]), P.ROOF_MOSS)
	if not mono:
		for i: int in 5:
			var k: float = float(i + 1) / 6.0
			ci.draw_circle(Vector2(-54, -38).lerp(Vector2(-11, -92), k) + Vector2(3, 3), 2.5, P.SPARKLE if i % 2 == 0 else P.SPARKLE_LILAC, true, -1.0, true)
	# Tall crook with a big hanging lantern: the cottage's signature shape.
	var crook: PackedVector2Array = PackedVector2Array([Vector2(40, 0), Vector2(40, -132)])
	crook.append_array(arc_pts(Vector2(26, -132), 14.0, 14.0, 0.0, -PI, 8))
	ci.draw_polyline(crook, lc(), 6.0 + lw * 2.0, true)
	ci.draw_polyline(crook, fc(P.WOOD), 6.0, true)
	stroke(Vector2(12, -132), Vector2(12, -122), 1.5, P.TIMBER, false)
	var pulse: float = 1.0 + 0.25 * sin(t * 2.4) + flash
	glow(Vector2(12, -102), 70.0, P.GLOW, pulse)
	poly(PackedVector2Array([Vector2(0, -120), Vector2(24, -120), Vector2(12, -132)]), P.TIMBER)
	box(1, -120, 23, -86, P.LANTERN)
	if not mono:
		ci.draw_circle(Vector2(12, -103), 6.0, P.LANTERN_CORE, true, -1.0, true)
	box(-1, -88, 25, -82, P.TIMBER)


# Creatures. Local box: about 40 tall, anchored at the feet, facing right.

func creature(kind: int, pos: Vector2, size: float, face_left: bool, phase: float, slowed: bool) -> void:
	begin(pos, size / 40.0, face_left)
	var step: float = t * (13.0 if kind == Creature.FAST else 8.0) + phase
	match kind:
		Creature.BASIC:
			_nightling(step)
		Creature.FAST:
			_dasher(step)
		Creature.ARMORED:
			_shellback(step)
		Creature.SWARM:
			_mite(step)
	if slowed:
		_drowsy(kind)
	end()


func _eye(c: Vector2, r: float) -> void:
	glow(c, r * 3.0, P.EYE, 0.8)
	ellipse(c, r, r * 1.2, P.EYE, true)
	if not mono:
		ci.draw_circle(c + Vector2(r * 0.35, r * 0.1), r * 0.5, P.INK_LINE, true, -1.0, true)


func _nightling(step: float) -> void:
	shadow(15.0)
	var bob: float = absf(sin(step)) * -3.0
	ellipse(Vector2(-7, -3 + minf(0.0, sin(step) * 3.0)), 6.0, 3.5, P.CREATURE_BASIC.darkened(0.2))
	ellipse(Vector2(8, -3 + minf(0.0, -sin(step) * 3.0)), 6.0, 3.5, P.CREATURE_BASIC.darkened(0.2))
	poly(PackedVector2Array([Vector2(-12, -30 + bob), Vector2(-7, -47 + bob), Vector2(-1, -33 + bob)]), P.CREATURE_BASIC)
	poly(PackedVector2Array([Vector2(3, -34 + bob), Vector2(11, -48 + bob), Vector2(14, -29 + bob)]), P.CREATURE_BASIC)
	var fuzz: PackedVector2Array = PackedVector2Array()
	for i: int in 22:
		var a: float = TAU * float(i) / 22.0
		var r: float = 17.0 if i % 2 == 0 else 19.0
		fuzz.append(Vector2(cos(a) * r, -20.0 + bob + sin(a) * r * 0.95))
	poly(fuzz, P.CREATURE_BASIC)
	if not mono:
		ci.draw_colored_polygon(ellipse_pts(Vector2(2, -13 + bob), 9.0, 6.0, 12), P.CREATURE_BASIC.lightened(0.25))
	_eye(Vector2(4, -23 + bob), 4.0)
	_eye(Vector2(12, -23 + bob), 3.6)
	if not mono:
		ci.draw_arc(Vector2(9, -16 + bob), 3.5, 0.3, PI - 0.3, 8, P.INK_LINE, 1.6, true)


func _dasher(step: float) -> void:
	shadow(18.0)
	# A lean, long-eared runner caught mid-leap: legs reach out front and back.
	var reach: float = sin(step) * 0.5 + 0.5
	var leg_col: Color = P.CREATURE_FAST.darkened(0.25)
	stroke(Vector2(-10, -14), Vector2(-20 - 4.0 * reach, -3), 3.0, leg_col)
	stroke(Vector2(-4, -13), Vector2(-12 + 4.0 * reach, -1), 3.0, leg_col)
	stroke(Vector2(8, -14), Vector2(16 + 5.0 * reach, -4), 3.0, leg_col)
	stroke(Vector2(12, -15), Vector2(22 + 3.0 * reach, -7), 3.0, leg_col)
	circle(Vector2(-19, -21), 5.5, P.CREATURE_FAST.lightened(0.3))
	ellipse(Vector2(-2, -18), 17.0, 9.5, P.CREATURE_FAST)
	poly(PackedVector2Array([Vector2(12, -30), Vector2(-6, -50), Vector2(-1, -48), Vector2(17, -31)]), P.CREATURE_FAST)
	poly(PackedVector2Array([Vector2(16, -30), Vector2(4, -53), Vector2(9, -52), Vector2(21, -30)]), P.CREATURE_FAST)
	poly(PackedVector2Array([Vector2(8, -30), Vector2(22, -32), Vector2(30, -23), Vector2(22, -17), Vector2(10, -18)]), P.CREATURE_FAST)
	if not mono:
		ci.draw_circle(Vector2(30, -23), 2.0, P.INK_LINE, true, -1.0, true)
	_eye(Vector2(18, -25), 3.8)
	if not mono:
		for i: int in 3:
			var y: float = -22.0 + float(i) * 6.0
			ci.draw_line(Vector2(-44 - float(i) * 3.0, y), Vector2(-36, y), Color(P.SPARKLE, 0.55), 2.0, true)


func _shellback(step: float) -> void:
	shadow(27.0)
	for i: int in 4:
		var x: float = -17.0 + float(i) * 11.0
		var lift: float = minf(0.0, sin(step + float(i) * 1.6) * 2.5)
		ellipse(Vector2(x, -3 + lift), 5.0, 3.5, P.CREATURE_ARMOR.darkened(0.25))
	poly(PackedVector2Array([Vector2(29, -16), Vector2(36, -22), Vector2(33, -13)]), P.CREATURE_ARMOR)
	circle(Vector2(25, -12), 8.5, P.CREATURE_ARMOR)
	_eye(Vector2(28, -14), 3.0)
	var shell: PackedVector2Array = arc_pts(Vector2(0, -8), 27.0, 27.0, PI, TAU, 18)
	poly(shell, P.CREATURE_ARMOR_SHELL)
	if not mono:
		ci.draw_arc(Vector2(-27, -8), 22.0, -0.95, -0.05, 8, Color(P.INK_LINE, 0.7), 2.0, true)
		ci.draw_arc(Vector2(27, -8), 22.0, PI + 0.05, PI + 0.95, 8, Color(P.INK_LINE, 0.7), 2.0, true)
		ci.draw_line(Vector2(0, -35), Vector2(0, -9), Color(P.INK_LINE, 0.7), 2.0, true)
		for x: float in [-13.0, 13.0]:
			ci.draw_circle(Vector2(x, -24), 2.0, P.STONE, true, -1.0, true)
	box(-28, -11, 28, -5, P.CREATURE_ARMOR)
	circle(Vector2(-3, -36), 4.0, P.MEADOW_LIGHT, true)
	circle(Vector2(3, -37), 3.5, P.MEADOW_LIGHT, true)


func _mite(step: float) -> void:
	shadow(8.0)
	var hop: float = absf(sin(step * 1.3)) * -5.0
	stroke(Vector2(-3, -6 + hop), Vector2(-5, -1), 1.2, P.CREATURE_SWARM.darkened(0.3), false)
	stroke(Vector2(3, -6 + hop), Vector2(5, -1), 1.2, P.CREATURE_SWARM.darkened(0.3), false)
	stroke(Vector2(1, -14 + hop), Vector2(5, -23 + hop), 1.2, P.INK_LINE, false)
	stroke(Vector2(-2, -14 + hop), Vector2(-5, -22 + hop), 1.2, P.INK_LINE, false)
	circle(Vector2(5, -23 + hop), 2.2, P.SPARKLE_LILAC, false)
	circle(Vector2(-5, -22 + hop), 2.2, P.SPARKLE_LILAC, false)
	glow(Vector2(0, -23 + hop), 8.0, P.SPARKLE_LILAC, 0.8)
	circle(Vector2(0, -9 + hop), 7.5, P.CREATURE_SWARM)
	_eye(Vector2(3, -10 + hop), 2.4)


## Drowsy swirl over a slowed creature, so slow never shows by color alone.
func _drowsy(kind: int) -> void:
	if mono:
		return
	var top: float = -30.0 if kind == Creature.SWARM else -56.0
	for i: int in 2:
		var c: Vector2 = Vector2(-6.0 + float(i) * 12.0, top - float(i) * 6.0 + sin(t * 3.0 + float(i)) * 2.0)
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 14:
			var a: float = float(k) * 0.55 + t * 2.0
			pts.append(c + Vector2(cos(a), sin(a)) * (1.0 + float(k) * 0.35))
		ci.draw_polyline(pts, P.INK_LINE, 3.4, true)
		ci.draw_polyline(pts, P.FLOUR, 1.6, true)


# Map pieces.

## The gate across a road. `across` is the unit vector across the road.
func gate(c: Vector2, across: Vector2, half_width: float, height: float, closed: bool, pulse: float) -> void:
	if not closed:
		var r: float = half_width * (1.0 + 0.08 * sin(t * 4.0))
		for i: int in 12:
			var a0: float = TAU * float(i) / 12.0 + t * 0.6
			ci.draw_arc(c, r, a0, a0 + 0.3, 6, P.INK_LINE, lw * 3.4, true)
			ci.draw_arc(c, r, a0, a0 + 0.3, 6, Color(P.ROUTE, 0.75 + 0.25 * pulse), lw * 1.6, true)
		_gate_panel(c, across, half_width * 0.7, height * 0.7, 0.35)
		return
	_gate_panel(c, across, half_width, height, 1.0)


func _gate_panel(c: Vector2, across: Vector2, hw: float, h: float, alpha: float) -> void:
	var l: Vector2 = c - across * hw
	var r: Vector2 = c + across * hw
	var up: Vector2 = Vector2(0.0, -h)
	var panel: PackedVector2Array = PackedVector2Array([l + up * 0.15, r + up * 0.15, r + up * 0.85, l + up * 0.85])
	if alpha < 1.0:
		ci.draw_colored_polygon(panel, Color(P.PLASTER, 0.25))
		var closed: PackedVector2Array = panel.duplicate()
		closed.append(panel[0])
		ci.draw_polyline(closed, Color(P.PLASTER, 0.7), lw, true)
		return
	ci.draw_colored_polygon(PackedVector2Array([l + Vector2(0, h * 0.06), r + Vector2(0, h * 0.06), r + Vector2(0, h * 0.14), l + Vector2(0, h * 0.14)]), Color(0.05, 0.03, 0.1, 0.3))
	poly(panel, P.WOOD)
	for i: int in 5:
		var k: float = (float(i) + 0.5) / 5.0
		var b: Vector2 = l.lerp(r, k) + up * 0.15
		detail(b, b + up * 0.78, lw * 0.8, P.TIMBER)
	detail(l + up * 0.2, r + up * 0.8, lw * 1.2, P.TIMBER)
	stroke(l + up * 0.45, r + up * 0.45, lw * 1.2, P.WOOD)
	for p: Vector2 in [l, r]:
		stroke(p, p + up, lw * 2.2, P.TIMBER)
		lantern(p + up * 1.12, h * 0.1, 1.0)


func tree(c: Vector2, size: float, kind: int) -> void:
	begin(c, size / 100.0)
	shadow(30.0)
	if kind == 0:
		box(-6, -34, 6, 0, P.TIMBER)
		circle(Vector2(-16, -48), 22.0, P.TREE_DARK)
		circle(Vector2(16, -50), 22.0, P.TREE_DARK)
		circle(Vector2(0, -68), 26.0, P.TREE)
		if not mono:
			ci.draw_circle(Vector2(-8, -76), 8.0, P.MEADOW_LIGHT, true, -1.0, true)
	else:
		box(-5, -16, 5, 0, P.TIMBER)
		poly(PackedVector2Array([Vector2(-30, -14), Vector2(30, -14), Vector2(0, -60)]), P.TREE_DARK)
		poly(PackedVector2Array([Vector2(-24, -44), Vector2(24, -44), Vector2(0, -96)]), P.TREE)
	end()


func cottage(c: Vector2, size: float, roof: Color, flip: bool) -> void:
	begin(c, size / 100.0, flip)
	shadow(42.0)
	box(16, -78, 28, -44, P.STONE)
	box(-36, -40, 36, 0, P.PLASTER)
	detail(Vector2(-36, -20), Vector2(36, -20), 2.0, P.TIMBER)
	box(-8, -24, 8, 0, P.TIMBER)
	window(-28, -32, -16, -20, 0.9)
	window(16, -32, 28, -20, 0.9)
	poly(PackedVector2Array([Vector2(-44, -36), Vector2(44, -36), Vector2(0, -74)]), roof)
	end()


func hearth_hall(c: Vector2, size: float) -> void:
	begin(c, size / 200.0)
	shadow(100.0)
	box(42, -150, 58, -100, P.STONE)
	box(-62, -140, -48, -100, P.STONE)
	box(-92, -72, 92, 0, P.PLASTER)
	for x: float in [-62.0, -32.0, 32.0, 62.0]:
		detail(Vector2(x, -72), Vector2(x, 0), 2.5, P.TIMBER)
	detail(Vector2(-92, -38), Vector2(92, -38), 2.5, P.TIMBER)
	window(-80, -62, -66, -46, 1.0)
	window(-56, -62, -40, -46, 1.0)
	window(40, -62, 56, -46, 1.0)
	window(66, -62, 80, -46, 1.0)
	poly(PackedVector2Array([Vector2(-106, -68), Vector2(106, -68), Vector2(72, -128), Vector2(-72, -128)]), P.ROOF_CLAY)
	glow(Vector2(0, -22), 60.0, P.GLOW, 1.3)
	var door: PackedVector2Array = arc_pts(Vector2(0, -30), 18.0, 18.0, PI, TAU, 10)
	door.append(Vector2(18, 0))
	door.append(Vector2(-18, 0))
	poly(door, P.LANTERN)
	detail(Vector2(0, -46), Vector2(0, 0), 2.0, P.TIMBER)
	circle(Vector2(0, -98), 17.0, P.CARD)
	heart(Vector2(0, -97), 10.0, P.HEART)
	for x: float in [-30.0, 30.0]:
		stroke(Vector2(x, 0), Vector2(x, -40), 3.0, P.TIMBER, false)
		lantern(Vector2(x, -46), 5.0, 1.0)
	end()


## Dark thicket where the night creatures come from.
func thicket(c: Vector2, size: float, blink: float) -> void:
	begin(c, size / 260.0)
	for i: int in 9:
		var x: float = -130.0 + float(i) * 32.5
		var r: float = 34.0 + float((i * 7) % 3) * 8.0
		var y: float = -40.0 - absf(float(i) - 4.0) * 8.0
		circle(Vector2(x, y), r, P.TREE_DARK if i % 2 == 0 else P.HILL_NEAR)
	ellipse(Vector2(0, -26), 50.0, 34.0, Color("16122a"), false)
	if not mono:
		var eyes: Array[Vector2] = [Vector2(-22, -30), Vector2(18, -22), Vector2(-2, -44), Vector2(-70, -54), Vector2(76, -50)]
		for i: int in eyes.size():
			var open: float = clampf(sin(blink * 0.9 + float(i) * 2.1) * 4.0 + 2.0, 0.0, 1.0)
			if open <= 0.05:
				continue
			for dx: float in [-5.0, 5.0]:
				var e: Vector2 = eyes[i] + Vector2(dx, 0)
				ci.draw_circle(e, 9.0, Color(P.EYE, 0.12 * open), true, -1.0, true)
				ci.draw_colored_polygon(ellipse_pts(e, 3.0, 3.6 * open, 10), P.EYE)
	end()


# Small icons for the HUD and effects.

func heart(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 28:
		var a: float = TAU * float(i) / 28.0
		var x: float = 16.0 * pow(sin(a), 3.0)
		var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * (r / 16.0))
	poly(pts, col)


func coin(c: Vector2, r: float) -> void:
	circle(c, r, P.COIN)
	if not mono:
		ci.draw_arc(c, r * 0.68, 0.0, TAU, 20, P.ROOF_CLAY, r * 0.12, true)
	star(c, r * 0.4, P.ROOF_CLAY)


func moon(c: Vector2, r: float) -> void:
	# Outer circle minus a circle offset right: a crescent lit on the left.
	var pts: PackedVector2Array = arc_pts(c, r, r, 1.016, TAU - 1.016, 20)
	var inner: PackedVector2Array = arc_pts(c + Vector2(r * 0.5, 0.0), r * 0.85, r * 0.85, -1.5384, -4.7448, 16)
	pts.append_array(inner.slice(1, inner.size() - 1))
	poly(pts, P.MOON)


func star(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 - PI / 2.0
		var rr: float = r if i % 2 == 0 else r * 0.38
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, fc(col))
