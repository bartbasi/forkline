# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Silhouettes
extends RefCounted
## Draws every tower and creature in the dusk storybook look (docs/art/THEME.md).
## Ids and names are in docs/art/NAMES.md.
##
## Towers: `center` is the cell center and `size` the cell side, in canvas
## pixels. The building stands on the build spot with its ground line at
## center.y + 0.30 * size. It stays within 0.52 * size left and right of the
## center and reaches at most 0.85 * size above it, so a tall tower may cover
## the lower part of the cell above. Tiers and specs follow one rule:
## - Tier 1 is the plain building.
## - Each tier above 1 adds one stone step under the building (tier 2: one,
##   tier 3: two), so the building stands higher and its base gets wider.
## - At tier 3 the spec replaces the tower's signature piece (roof, arm, bell
##   top, bow, rockets, chimney). The building below it never changes.
##
## Creatures: `center` is the creature's position and `size` the side of its
## drawing box (enemy_size() gives the box for a map cell). Walkers stand with
## their feet at center.y + 0.36 * size, facing right; flip the node to face
## left. Flyers hover above a separate shadow, so flying never shows by color
## alone. `frame` steps the walk or flap cycle (4 frames, any int works).
##
## Every draw function takes an optional `flat` color. With it, the whole
## drawing is that one color: the silhouette.

const TOWERS: Array[StringName] = [&"sling_post", &"pumpkin_catapult", &"lullaby_bell", &"longbow_loft", &"firework_tower", &"bakery"]
## Spec ids per tower: index 0 and 1 are the `spec` argument at tier 3.
const SPECS: Dictionary[StringName, Array] = {
	&"sling_post": [&"quickshot", &"stone_sling"],
	&"pumpkin_catapult": [&"prize_pumpkin", &"jam_pot"],
	&"lullaby_bell": [&"hush_bell", &"night_bell"],
	&"longbow_loft": [&"giant_bow", &"triple_bow"],
	&"firework_tower": [&"star_bloom", &"skyrocket"],
	&"bakery": [&"grand_oven", &"spice_kitchen"],
}
const CREATURES: Array[StringName] = [&"scamp", &"pip", &"skitter", &"flitter", &"shellback", &"bubbler", &"puffball", &"puff", &"mender", &"gatecrasher", &"dusk_moth"]
const BOSSES: Array[StringName] = [&"grumblesack", &"ironshell", &"moon_moth", &"old_tusk"]
const FLYERS: Array[StringName] = [&"flitter", &"dusk_moth", &"moon_moth"]
## Drawing box per creature, as a fraction of the map cell. On the Fold5 cover
## screen a cell is about 49 dp, so a Scamp is about 28 dp and a boss about 57 dp.
const ENEMY_SIZE: Dictionary[StringName, float] = {
	&"scamp": 0.58, &"pip": 0.4, &"skitter": 0.6, &"flitter": 0.56, &"shellback": 0.72,
	&"bubbler": 0.6, &"puffball": 0.68, &"puff": 0.4, &"mender": 0.62, &"gatecrasher": 0.76,
	&"dusk_moth": 0.68, &"grumblesack": 1.16, &"ironshell": 1.16, &"moon_moth": 1.2, &"old_tusk": 1.2,
}
## Tower ground line below the cell center, as a fraction of the cell.
const TOWER_GROUND: float = 0.30
## Creature feet below the creature center, as a fraction of its box.
const FEET: float = 0.36
const STEP_HEIGHT: float = 8.0

const NO_FLAT: Color = Color(0.0, 0.0, 0.0, 0.0)


# Public API (contract 3.9).

static func draw_tower(canvas: CanvasItem, type: StringName, tier: int, spec: int, center: Vector2, size: float, flat: Color = NO_FLAT) -> void:
	tower_into(InkPen.new(canvas, flat), type, tier, spec, center, size)


static func draw_enemy(canvas: CanvasItem, type: StringName, center: Vector2, size: float, frame: int, flat: Color = NO_FLAT) -> void:
	enemy_into(InkPen.new(canvas, flat), type, center, size, frame)


## The drawing box side for a creature on a map with cells of `cell` pixels.
static func enemy_size(type: StringName, cell: float) -> float:
	var k: float = ENEMY_SIZE.get(type, 0.6)
	return k * cell


static func has_tower(type: StringName) -> bool:
	return TOWERS.has(type)


static func has_enemy(type: StringName) -> bool:
	return CREATURES.has(type) or BOSSES.has(type)


static func is_flyer(type: StringName) -> bool:
	return FLYERS.has(type)


## The bubble ring around a Bubbler while its bubble is up.
static func draw_bubble(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(size * 0.03, 1.5, 4.0)
	pen.begin(center, size / 100.0)
	pen.path(_closed(InkPen.ellipse_pts(Vector2(0, 0), 50.0, 50.0, 40)), 4.0, Palette.BUBBLE)
	pen.detail_path(InkPen.arc_pts(Vector2(0, 0), 40.0, 40.0, -2.6, -1.9, 6), 4.0, Palette.BUBBLE)


## The drowsy "z z" mark over a slowed creature.
static func draw_drowsy(canvas: CanvasItem, center: Vector2, size: float, frame: int) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(size * 0.035, 1.5, 4.0)
	pen.begin(center, size / 100.0)
	var lift: float = float(frame % 4) * 2.0
	for i: int in 2:
		var s: float = 13.0 - float(i) * 4.0
		var o: Vector2 = Vector2(6.0 + float(i) * 18.0, -62.0 - float(i) * 14.0 - lift)
		pen.path(PackedVector2Array([o, o + Vector2(s, 0), o + Vector2(0, s), o + Vector2(s, s)]), 4.0, Palette.FLOUR)


## The double chevron beside a tower that a Bakery boosts.
static func draw_boost(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var pen: InkPen = InkPen.new(canvas)
	pen.line_px = clampf(size * 0.025, 1.5, 4.0)
	pen.begin(center, size / 100.0)
	for i: int in 2:
		var y: float = -8.0 - float(i) * 10.0
		pen.path(PackedVector2Array([Vector2(36, y + 6), Vector2(43, y), Vector2(50, y + 6)]), 4.0, Palette.LANTERN)


## Small icons for the HUD and cards: &"heart", &"coin", &"moon", &"star",
## &"gate". `size` is the icon's box side.
static func draw_glyph(canvas: CanvasItem, glyph: StringName, center: Vector2, size: float, flat: Color = NO_FLAT) -> void:
	var pen: InkPen = InkPen.new(canvas, flat)
	pen.line_px = clampf(size * 0.06, 1.0, 4.0)
	pen.begin(center, size / 100.0)
	match glyph:
		&"heart":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 32:
				var a: float = TAU * float(i) / 32.0
				pts.append(Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * 2.6 + Vector2(0, -4))
			pen.poly(pts, Palette.HEART)
		&"coin":
			pen.circle(Vector2.ZERO, 40.0, Palette.COIN)
			pen.detail_path(_closed(InkPen.ellipse_pts(Vector2.ZERO, 28.0, 28.0, 24)), 5.0, Palette.ROOF_CLAY)
			pen.star(Vector2.ZERO, 17.0, Palette.ROOF_CLAY)
		&"moon":
			var outer: PackedVector2Array = InkPen.arc_pts(Vector2.ZERO, 40.0, 40.0, 1.016, TAU - 1.016, 24)
			var inner: PackedVector2Array = InkPen.arc_pts(Vector2(20.0, 0.0), 34.0, 34.0, -1.5384, -4.7448, 18)
			outer.append_array(inner.slice(1, inner.size() - 1))
			pen.poly(outer, Palette.MOON)
		&"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 10:
				var a: float = TAU * float(i) / 10.0 - PI / 2.0
				var r: float = 44.0 if i % 2 == 0 else 19.0
				pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, 3))
			pen.poly(pts, Palette.HONEY)
		&"gate":
			pen.box(-34, -18, 34, 18, Palette.WOOD)
			for x: float in [-17.0, 0.0, 17.0]:
				pen.detail(Vector2(x, -15), Vector2(x, 15), 3.0, Palette.TIMBER)
			pen.stroke(Vector2(-40, 30), Vector2(-40, -34), 8.0, Palette.TIMBER)
			pen.stroke(Vector2(40, 30), Vector2(40, -34), 8.0, Palette.TIMBER)
			pen.circle(Vector2(-40, -40), 7.0, Palette.LANTERN)
			pen.circle(Vector2(40, -40), 7.0, Palette.LANTERN)
		_:
			pen.circle(Vector2.ZERO, 30.0, Palette.STONE)


# Drawing into a pen. Used by the public functions above and by the tests.

static func tower_into(pen: InkPen, type: StringName, tier: int, spec: int, center: Vector2, size: float) -> void:
	var t: int = clampi(tier, 1, 3)
	var s: int = spec if t == 3 else -1
	var scale: float = size / 100.0
	var ground: Vector2 = center + Vector2(0.0, TOWER_GROUND * size)
	pen.line_px = clampf(size * 0.03, 1.2, 5.0)
	pen.begin(ground, scale)
	pen.shadow(Vector2(0, -1), 44.0)
	# Stone steps: one per tier above 1, each narrower than the one below.
	for i: int in t - 1:
		var half: float = 45.0 - float(i) * 6.0
		var y0: float = -STEP_HEIGHT * float(i)
		pen.box(-half, y0 - STEP_HEIGHT, half, y0, Palette.STONE)
		pen.detail(Vector2(-half + 4.0, y0 - STEP_HEIGHT * 0.5), Vector2(half - 4.0, y0 - STEP_HEIGHT * 0.5), 1.2, Palette.STONE_DARK)
	pen.begin(ground + Vector2(0.0, -STEP_HEIGHT * float(t - 1) * scale), scale)
	match type:
		&"sling_post":
			_sling_post(pen, s)
		&"pumpkin_catapult":
			_pumpkin_catapult(pen, s)
		&"lullaby_bell":
			_lullaby_bell(pen, s)
		&"longbow_loft":
			_longbow_loft(pen, s)
		&"firework_tower":
			_firework_tower(pen, s)
		&"bakery":
			_bakery(pen, s)
		_:
			pen.box(-30, -60, 30, 0, Palette.STONE)


static func enemy_into(pen: InkPen, type: StringName, center: Vector2, size: float, frame: int) -> void:
	var f: int = posmod(frame, 4)
	pen.line_px = clampf(size * 0.045, 1.2, 5.0)
	pen.begin(center, size / 100.0)
	match type:
		&"scamp":
			_scamp(pen, f)
		&"pip":
			_pip(pen, f)
		&"skitter":
			_skitter(pen, f)
		&"flitter":
			_flitter(pen, f)
		&"shellback":
			_shellback(pen, f, false)
		&"bubbler":
			_bubbler(pen, f)
		&"puffball":
			_puffball(pen, f)
		&"puff":
			_puff(pen, f)
		&"mender":
			_mender(pen, f)
		&"gatecrasher":
			_gatecrasher(pen, f)
		&"dusk_moth":
			_moth(pen, f, false)
		&"grumblesack":
			_grumblesack(pen, f)
		&"ironshell":
			_shellback(pen, f, true)
		&"moon_moth":
			_moth(pen, f, true)
		&"old_tusk":
			_old_tusk(pen, f)
		_:
			pen.circle(Vector2(0, 6), 28.0, Palette.CREATURE_BASIC)


# Towers. Local units: 100 is one cell, ground at y 0, up is negative.

static func _sling_post(pen: InkPen, spec: int) -> void:
	pen.poly(PackedVector2Array([Vector2(-38, 0), Vector2(-28, 0), Vector2(-16, -46), Vector2(-25, -46)]), Palette.WOOD)
	pen.poly(PackedVector2Array([Vector2(28, 0), Vector2(38, 0), Vector2(25, -46), Vector2(16, -46)]), Palette.WOOD)
	pen.stroke(Vector2(-29, -8), Vector2(18, -40), 4.0, Palette.TIMBER)
	pen.stroke(Vector2(29, -8), Vector2(-18, -40), 4.0, Palette.TIMBER)
	pen.box(-33, -52, 33, -45, Palette.WOOD)
	pen.box(-23, -70, 23, -52, Palette.PLASTER)
	pen.window(-8, -67, 8, -55)
	if spec == 0:
		# Quickshot: two cabins side by side, a double peak.
		pen.poly(PackedVector2Array([Vector2(-34, -68), Vector2(4, -68), Vector2(-15, -92)]), Palette.ROOF_CLAY)
		pen.poly(PackedVector2Array([Vector2(-4, -68), Vector2(34, -68), Vector2(15, -92)]), Palette.ROOF_CLAY)
		pen.stroke(Vector2(-23, -58), Vector2(-33, -58), 3.0, Palette.TIMBER, false)
		pen.lantern(Vector2(-36, -48), 4.5)
		pen.stroke(Vector2(23, -58), Vector2(33, -58), 3.0, Palette.TIMBER, false)
		pen.lantern(Vector2(36, -48), 4.5)
	elif spec == 1:
		# Stone Sling: a boulder in a net hangs from a beam off the roof.
		pen.poly(PackedVector2Array([Vector2(-31, -68), Vector2(31, -68), Vector2(0, -92)]), Palette.ROOF_CLAY)
		pen.stroke(Vector2(-6, -86), Vector2(38, -76), 4.0, Palette.TIMBER)
		pen.stroke(Vector2(36, -76), Vector2(36, -66), 1.5, Palette.TIMBER, false)
		pen.circle(Vector2(36, -56), 11.0, Palette.STONE)
		pen.detail_path(PackedVector2Array([Vector2(26, -60), Vector2(36, -50), Vector2(46, -60)]), 1.4, Palette.TIMBER)
		pen.detail(Vector2(36, -67), Vector2(36, -45), 1.4, Palette.TIMBER)
		pen.stroke(Vector2(-23, -58), Vector2(-33, -58), 3.0, Palette.TIMBER, false)
		pen.lantern(Vector2(-36, -48), 4.5)
	else:
		pen.poly(PackedVector2Array([Vector2(-31, -68), Vector2(31, -68), Vector2(0, -92)]), Palette.ROOF_CLAY)
		pen.stroke(Vector2(23, -58), Vector2(33, -58), 3.0, Palette.TIMBER, false)
		pen.lantern(Vector2(36, -48), 4.5)


static func _pumpkin_catapult(pen: InkPen, spec: int) -> void:
	# The arm first, so the shed sits in front of its lower end.
	var cup: Vector2 = Vector2(30, -58)
	pen.stroke(Vector2(28, 0), Vector2(20, -30), 5.0, Palette.WOOD)
	pen.stroke(Vector2(44, 0), Vector2(22, -30), 5.0, Palette.WOOD)
	pen.stroke(Vector2(2, -20), cup, 6.0, Palette.WOOD)
	pen.circle(Vector2(21, -31), 4.0, Palette.TIMBER)
	if spec == 0:
		# Prize Pumpkin: a huge pumpkin in a bigger cup.
		_pumpkin(pen, cup + Vector2(0, -15), 17.0, 14.0)
	elif spec == 1:
		# Jam Pot: a jar with a tied cloth lid.
		var c: Vector2 = cup + Vector2(0, -12)
		pen.poly(PackedVector2Array([c + Vector2(-11, -9), c + Vector2(11, -9), c + Vector2(13, 4), c + Vector2(8, 12), c + Vector2(-8, 12), c + Vector2(-13, 4)]), Palette.JAM)
		pen.poly(PackedVector2Array([c + Vector2(-16, -9), c + Vector2(16, -9), c + Vector2(11, -17), c + Vector2(-11, -17)]), Palette.PLASTER)
		pen.circle(c + Vector2(0, -21), 4.5, Palette.PLASTER)
		pen.detail_circle(c + Vector2(-4, 1), 2.6, Palette.LANTERN_CORE)
		pen.detail_circle(c + Vector2(9, 14), 2.0, Palette.JAM)
	else:
		_pumpkin(pen, cup + Vector2(0, -10), 12.0, 10.0)
	pen.box(-44, -30, 10, 0, Palette.PLASTER)
	pen.detail(Vector2(-44, -15), Vector2(10, -15), 2.0, Palette.TIMBER)
	pen.box(-24, -15, -12, 0, Palette.TIMBER)
	pen.window(-38, -26, -28, -17)
	pen.window(-8, -26, 2, -17)
	pen.poly(PackedVector2Array([Vector2(-50, -27), Vector2(16, -27), Vector2(-17, -54)]), Palette.ROOF_MOSS)


static func _pumpkin(pen: InkPen, c: Vector2, rx: float, ry: float) -> void:
	pen.stroke(c + Vector2(0, -ry), c + Vector2(3, -ry - 6.0), 3.0, Palette.ROOF_MOSS)
	pen.ellipse(c, rx, ry, Palette.PUMPKIN)
	pen.detail_path(InkPen.arc_pts(c, rx * 0.45, ry * 0.95, -PI * 0.5, PI * 0.5, 8), 1.5, Palette.ROOF_CLAY)
	pen.detail_path(InkPen.arc_pts(c, rx * 0.45, ry * 0.95, PI * 0.5, PI * 1.5, 8), 1.5, Palette.ROOF_CLAY)


static func _lullaby_bell(pen: InkPen, spec: int) -> void:
	pen.box(-26, -32, 26, 0, Palette.PLASTER)
	pen.door(Vector2(0, 0), 7.0, 18.0, Palette.TIMBER)
	pen.window(-20, -26, -11, -17)
	pen.window(11, -26, 20, -17)
	pen.box(-31, -39, 31, -32, Palette.TIMBER)
	var bell_lip: float = 15.0 if spec == 0 else 12.0
	if spec == 0:
		# Hush Bell: a wide onion dome over posts and a bigger bell.
		pen.stroke(Vector2(-24, -39), Vector2(-24, -60), 5.0, Palette.WOOD)
		pen.stroke(Vector2(24, -39), Vector2(24, -60), 5.0, Palette.WOOD)
		_bell(pen, Vector2(0, -62), bell_lip, 22.0)
		var dome: PackedVector2Array = PackedVector2Array([Vector2(-33, -60), Vector2(33, -60)])
		dome.append_array(InkPen.arc_pts(Vector2(0, -60), 33.0, 26.0, 0.0, -PI, 14))
		pen.poly(dome, Palette.ROOF_PLUM)
		pen.poly(PackedVector2Array([Vector2(-6, -84), Vector2(6, -84), Vector2(0, -96)]), Palette.ROOF_PLUM)
	elif spec == 1:
		# Night Bell: a tall pointed spire with a star on the tip.
		pen.stroke(Vector2(-20, -39), Vector2(-20, -60), 5.0, Palette.WOOD)
		pen.stroke(Vector2(20, -39), Vector2(20, -60), 5.0, Palette.WOOD)
		_bell(pen, Vector2(0, -60), bell_lip, 18.0)
		pen.poly(PackedVector2Array([Vector2(-27, -58), Vector2(27, -58), Vector2(0, -86)]), Palette.ROOF_SLATE)
		pen.glow(Vector2(0, -90), 12.0, Palette.MOON)
		pen.star(Vector2(0, -90), 7.0, Palette.MOON)
	else:
		# Tier 1 and 2: an open round arch with the bell inside, a moon on top.
		pen.stroke(Vector2(-22, -39), Vector2(-22, -58), 5.0, Palette.WOOD)
		pen.stroke(Vector2(22, -39), Vector2(22, -58), 5.0, Palette.WOOD)
		pen.path(InkPen.arc_pts(Vector2(0, -58), 22.0, 20.0, 0.0, -PI, 12), 5.0, Palette.WOOD)
		_bell(pen, Vector2(0, -74), bell_lip, 30.0)
		var moon: PackedVector2Array = InkPen.arc_pts(Vector2(0, -86), 7.0, 7.0, 1.016, TAU - 1.016, 12)
		var inner: PackedVector2Array = InkPen.arc_pts(Vector2(3.5, -86), 6.0, 6.0, -1.5384, -4.7448, 10)
		moon.append_array(inner.slice(1, inner.size() - 1))
		pen.poly(moon, Palette.MOON)


## A bell hanging from `top`, its lip `half` units each side, `height` tall.
static func _bell(pen: InkPen, top: Vector2, half: float, height: float) -> void:
	var lip: float = top.y + height
	var pts: PackedVector2Array = InkPen.arc_pts(Vector2(0, top.y + half * 0.55), half * 0.55, half * 0.55, PI, TAU, 8)
	pts.append(Vector2(half * 0.7, lip - height * 0.35))
	pts.append(Vector2(half, lip))
	pts.append(Vector2(-half, lip))
	pts.append(Vector2(-half * 0.7, lip - height * 0.35))
	pen.poly(pts, Palette.HONEY)
	pen.detail(Vector2(-half * 0.8, lip - 3.0), Vector2(half * 0.8, lip - 3.0), 1.6, Palette.GLOW)
	pen.circle(Vector2(0, lip + 2.5), 3.0, Palette.TIMBER)


static func _longbow_loft(pen: InkPen, spec: int) -> void:
	pen.poly(PackedVector2Array([Vector2(-19, 0), Vector2(19, 0), Vector2(15, -58), Vector2(-15, -58)]), Palette.STONE)
	for row: int in 4:
		var y: float = -12.0 - float(row) * 12.0
		var off: float = 6.0 if row % 2 == 0 else -5.0
		pen.detail(Vector2(-10 + off, y), Vector2(2 + off, y), 1.6, Palette.STONE_DARK)
	pen.door(Vector2(0, 0), 6.5, 15.0, Palette.TIMBER)
	pen.glow(Vector2(0, -38), 14.0, Palette.GLOW)
	pen.box(-3, -46, 3, -30, Palette.LANTERN)
	pen.box(-21, -66, 21, -57, Palette.STONE)
	pen.box(-21, -72, -14, -66, Palette.STONE)
	pen.box(-3.5, -72, 3.5, -66, Palette.STONE)
	pen.box(14, -72, 21, -66, Palette.STONE)
	if spec == 0:
		# Giant Bow: one huge bow, wider than the tower.
		_bow(pen, Vector2(0, -76), 46.0, 10.0, 6.5)
	elif spec == 1:
		# Triple Bow: three small bows side by side, the middle one higher.
		_bow(pen, Vector2(-30, -74), 16.0, 6.0, 4.0)
		_bow(pen, Vector2(30, -74), 16.0, 6.0, 4.0)
		_bow(pen, Vector2(0, -80), 16.0, 6.0, 4.0)
	else:
		_bow(pen, Vector2(0, -76), 42.0, 10.0, 5.5)


## A bow lying across at `mid`, `half` units each side, bending `bend` up,
## with an arrow standing up from its middle.
static func _bow(pen: InkPen, mid: Vector2, half: float, bend: float, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		mid + Vector2(-half, 0), mid + Vector2(-half * 0.6, -bend * 0.8), mid + Vector2(0, -bend),
		mid + Vector2(half * 0.6, -bend * 0.8), mid + Vector2(half, 0)])
	pen.detail(mid + Vector2(-half, 0), mid + Vector2(0, -bend * 0.3), 1.2, Palette.PLASTER)
	pen.detail(mid + Vector2(half, 0), mid + Vector2(0, -bend * 0.3), 1.2, Palette.PLASTER)
	pen.path(pts, width, Palette.WOOD)
	var tip: float = mid.y - bend - 2.0
	pen.stroke(mid + Vector2(0, 2), Vector2(mid.x, tip), width * 0.45, Palette.TIMBER)
	pen.poly(PackedVector2Array([Vector2(mid.x - width * 0.8, tip), Vector2(mid.x + width * 0.8, tip), Vector2(mid.x, tip - width * 1.4)]), Palette.LANTERN_CORE)


static func _firework_tower(pen: InkPen, spec: int) -> void:
	var colors: Array[Color] = [Palette.ROOF_CLAY, Palette.HONEY, Palette.ROOF_SLATE, Palette.HONEY, Palette.ROOF_CLAY]
	if spec == 0:
		# Star Bloom: five small rockets in a wide fan.
		for i: int in 5:
			pen.rotate_about(Vector2(0, -44), (float(i) - 2.0) * 0.36)
			_rocket(pen, Vector2(0, -64), 0.8, colors[i])
			pen.unrotate()
	elif spec == 1:
		# Skyrocket: one big rocket upright in a launch frame.
		pen.stroke(Vector2(-20, -44), Vector2(-9, -74), 4.0, Palette.TIMBER)
		pen.stroke(Vector2(20, -44), Vector2(9, -74), 4.0, Palette.TIMBER)
		_rocket(pen, Vector2(0, -66), 1.2, Palette.ROOF_CLAY)
	else:
		for i: int in 3:
			pen.rotate_about(Vector2(0, -44), (float(i) - 1.0) * 0.5)
			_rocket(pen, Vector2(0, -66), 1.0, colors[i + 1])
			pen.unrotate()
	pen.box(-36, -38, 36, 0, Palette.PLASTER)
	pen.detail(Vector2(-36, -19), Vector2(36, -19), 2.0, Palette.TIMBER)
	pen.box(-7, -18, 7, 0, Palette.TIMBER)
	pen.window(-29, -32, -18, -22)
	pen.window(18, -32, 29, -22)
	pen.poly(PackedVector2Array([Vector2(-43, -35), Vector2(43, -35), Vector2(37, -48), Vector2(-37, -48)]), Palette.ROOF_PLUM)


## One rocket centered on `c`, standing up, `k` times the normal size.
static func _rocket(pen: InkPen, c: Vector2, k: float, body: Color) -> void:
	var w: float = 6.0 * k
	var h: float = 15.0 * k
	pen.poly(PackedVector2Array([c + Vector2(-w, h * 0.3), c + Vector2(-w * 2.0, h + 4.0 * k), c + Vector2(-w, h)]), Palette.TIMBER)
	pen.poly(PackedVector2Array([c + Vector2(w, h * 0.3), c + Vector2(w * 2.0, h + 4.0 * k), c + Vector2(w, h)]), Palette.TIMBER)
	pen.box(c.x - w, c.y - h, c.x + w, c.y + h, body)
	pen.poly(PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c + Vector2(0, -h - w * 1.9)]), Palette.ROOF_PLUM)
	pen.star(c + Vector2(0, -h * 0.2), w * 0.7, Palette.PLASTER)


static func _bakery(pen: InkPen, spec: int) -> void:
	if spec == 0:
		# Grand Oven: two tall chimneys.
		_chimney(pen, 4.0, 16.0, -80.0)
		_chimney(pen, 22.0, 33.0, -66.0)
	elif spec == 1:
		# Spice Kitchen: a pepper mill turret with a round knob.
		pen.box(10, -64, 32, -24, Palette.ROOF_CLAY)
		pen.detail(Vector2(10, -44), Vector2(32, -44), 2.0, Palette.TIMBER)
		pen.ellipse(Vector2(21, -66), 15.0, 8.0, Palette.TIMBER)
		pen.circle(Vector2(21, -79), 5.5, Palette.TIMBER)
	else:
		_chimney(pen, 16.0, 29.0, -76.0)
	var dome: PackedVector2Array = InkPen.arc_pts(Vector2(-4, 0), 42.0, 54.0, PI, TAU, 22)
	pen.poly(dome, Palette.PLASTER_SHADE)
	for row: int in 3:
		var y: float = -14.0 - float(row) * 13.0
		var half: float = 42.0 * sqrt(maxf(0.0, 1.0 - pow(y / 54.0, 2.0)))
		pen.detail(Vector2(-4.0 - half + 4.0, y), Vector2(-4.0 + half - 4.0, y), 1.4, Palette.STONE_DARK)
	var mouth: PackedVector2Array = InkPen.arc_pts(Vector2(-4, -12), 14.0, 14.0, PI, TAU, 10)
	mouth.append(Vector2(10, 0))
	mouth.append(Vector2(-18, 0))
	pen.poly(mouth, Palette.INK_LINE)
	pen.glow(Vector2(-4, -7), 24.0, Palette.GLOW, 1.4)
	pen.detail_poly(InkPen.ellipse_pts(Vector2(-4, -5), 9.0, 5.0, 12), Palette.GLOW)
	pen.detail_poly(InkPen.ellipse_pts(Vector2(-4, -4), 5.0, 3.0, 10), Palette.LANTERN_CORE)
	pen.window(-34, -30, -23, -20)


static func _chimney(pen: InkPen, x0: float, x1: float, top: float) -> void:
	pen.box(x0, top + 6.0, x1, -24, Palette.ROOF_CLAY)
	pen.box(x0 - 3.0, top, x1 + 3.0, top + 6.0, Palette.STONE_DARK)
	if not pen.is_flat():
		for i: int in 2:
			var k: float = float(i) * 0.5 + 0.25
			pen.detail_circle(Vector2((x0 + x1) * 0.5 + 4.0 * float(i), top - 7.0 - 9.0 * float(i)), 4.0 + 3.0 * k, Color(Palette.SMOKE, 0.45 - 0.15 * float(i)))


# Creatures. Local units: the box is 100 across, centered on the position,
# feet at y 36, facing right.

static func _bob(frame: int, amount: float) -> float:
	return -amount if frame % 2 == 1 else 0.0


static func _feet(pen: InkPen, xs: Array[float], col: Color, frame: int, rx: float) -> void:
	for i: int in xs.size():
		var lift: float = -4.0 if (i + frame) % 2 == 0 and frame % 2 == 1 else 0.0
		pen.ellipse(Vector2(xs[i], 33.0 + lift), rx, rx * 0.55, col)


static func _scamp(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 28.0)
	var b: float = _bob(frame, 4.0)
	_feet(pen, [-12.0, 12.0], Palette.CREATURE_BASIC.darkened(0.2), frame, 10.0)
	pen.poly(PackedVector2Array([Vector2(-24, -14 + b), Vector2(-14, -46 + b), Vector2(-3, -20 + b)]), Palette.CREATURE_BASIC)
	pen.poly(PackedVector2Array([Vector2(5, -21 + b), Vector2(19, -47 + b), Vector2(25, -12 + b)]), Palette.CREATURE_BASIC)
	pen.poly(_fuzzy(Vector2(0, 6 + b), 30.0, 28.0, 24, 3.5), Palette.CREATURE_BASIC)
	pen.detail_poly(InkPen.ellipse_pts(Vector2(3, 18 + b), 16.0, 9.0, 14), Palette.CREATURE_BASIC.lightened(0.25))
	pen.eye(Vector2(7, 0 + b), 6.5)
	pen.eye(Vector2(21, 0 + b), 5.8)
	pen.detail_path(InkPen.arc_pts(Vector2(15, 11 + b), 5.0, 4.0, 0.3, PI - 0.3, 6), 2.0, Palette.INK_LINE)


static func _pip(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 20.0)
	var b: float = _bob(frame, 8.0)
	pen.stroke(Vector2(-8, 26 + b), Vector2(-12, 36), 3.0, Palette.CREATURE_SWARM.darkened(0.3), false)
	pen.stroke(Vector2(8, 26 + b), Vector2(12, 36), 3.0, Palette.CREATURE_SWARM.darkened(0.3), false)
	pen.stroke(Vector2(-6, -6 + b), Vector2(-16, -36 + b), 3.5, Palette.INK_LINE, false)
	pen.stroke(Vector2(6, -6 + b), Vector2(16, -38 + b), 3.5, Palette.INK_LINE, false)
	pen.glow(Vector2(0, -38 + b), 18.0, Palette.SPARKLE_LILAC, 0.8)
	pen.circle(Vector2(-16, -38 + b), 6.5, Palette.SPARKLE_LILAC)
	pen.circle(Vector2(16, -40 + b), 6.5, Palette.SPARKLE_LILAC)
	pen.circle(Vector2(0, 12 + b), 21.0, Palette.CREATURE_SWARM)
	pen.eye(Vector2(8, 8 + b), 7.0)


static func _skitter(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 34.0)
	var reach: float = 1.0 if frame % 2 == 0 else 0.0
	var leg: Color = Palette.CREATURE_FAST.darkened(0.25)
	pen.stroke(Vector2(-22, 12), Vector2(-40 - 8.0 * reach, 33), 6.0, leg)
	pen.stroke(Vector2(-10, 14), Vector2(-22 + 8.0 * reach, 35), 6.0, leg)
	pen.stroke(Vector2(14, 12), Vector2(30 + 9.0 * reach, 30), 6.0, leg)
	pen.stroke(Vector2(22, 10), Vector2(42 + 5.0 * reach, 24), 6.0, leg)
	pen.circle(Vector2(-38, -2), 10.0, Palette.CREATURE_FAST.lightened(0.3))
	pen.ellipse(Vector2(-4, 4), 34.0, 18.0, Palette.CREATURE_FAST)
	pen.poly(PackedVector2Array([Vector2(16, -14), Vector2(-16, -48), Vector2(-7, -48), Vector2(26, -16)]), Palette.CREATURE_FAST)
	pen.poly(PackedVector2Array([Vector2(24, -16), Vector2(4, -52), Vector2(13, -52), Vector2(33, -16)]), Palette.CREATURE_FAST)
	pen.poly(PackedVector2Array([Vector2(12, -14), Vector2(36, -18), Vector2(49, -2), Vector2(36, 8), Vector2(14, 6)]), Palette.CREATURE_FAST)
	pen.detail_circle(Vector2(48, -2), 3.0, Palette.INK_LINE)
	pen.eye(Vector2(30, -6), 6.0)


static func _flitter(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 40), 20.0)
	var up: bool = frame % 2 == 0
	var tip_y: float = -38.0 if up else -10.0
	var b: float = -6.0 if up else 0.0
	for side: float in [-1.0, 1.0]:
		# The lower edge runs from the tip back to the body, with two finger
		# tips pushed out, so the edge between them reads as scallops.
		var shoulder: Vector2 = Vector2(10 * side, -14 + b)
		var tip: Vector2 = Vector2(48 * side, tip_y + b)
		var root: Vector2 = Vector2(12 * side, 2 + b)
		var out: Vector2 = Vector2(0, 1).rotated(-0.5 * side) * 7.0
		var w: PackedVector2Array = PackedVector2Array([shoulder, tip])
		for k: int in 5:
			var p: Vector2 = tip.lerp(root, float(k + 1) / 6.0)
			w.append(p + out if k % 2 == 1 else p)
		w.append(root)
		pen.poly(w, Palette.CREATURE_FLY.darkened(0.2))
	pen.poly(PackedVector2Array([Vector2(-14, -18 + b), Vector2(-12, -36 + b), Vector2(-3, -24 + b)]), Palette.CREATURE_FLY)
	pen.poly(PackedVector2Array([Vector2(3, -24 + b), Vector2(12, -36 + b), Vector2(14, -18 + b)]), Palette.CREATURE_FLY)
	pen.poly(_fuzzy(Vector2(0, -6 + b), 19.0, 19.0, 16, 2.0), Palette.CREATURE_FLY)
	pen.eye(Vector2(-6, -8 + b), 5.0)
	pen.eye(Vector2(7, -8 + b), 5.0)


static func _shellback(pen: InkPen, frame: int, boss: bool) -> void:
	var shell_col: Color = Palette.BOSS_SHELL if boss else Palette.CREATURE_ARMOR_SHELL
	var skin: Color = Palette.CREATURE_ARMOR
	pen.shadow(Vector2(0, 37), 46.0)
	for i: int in 4:
		var x: float = -30.0 + float(i) * 19.0
		var lift: float = -4.0 if (i + frame) % 2 == 0 and frame % 2 == 1 else 0.0
		pen.ellipse(Vector2(x, 31 + lift), 8.0, 6.0, skin.darkened(0.25))
	pen.poly(PackedVector2Array([Vector2(44, 6), Vector2(50, -2), Vector2(48, 10)]), skin)
	pen.circle(Vector2(38, 14), 13.0, skin)
	pen.eye(Vector2(42, 11), 4.5)
	if boss:
		# Ironshell: three tall plates along its back.
		for k: int in 3:
			var x: float = -24.0 + float(k) * 22.0
			var h: float = 34.0 if k == 1 else 26.0
			pen.poly(PackedVector2Array([Vector2(x - 11, -2), Vector2(x + 11, -2), Vector2(x + 2, -2 - h - 8.0)]), Palette.IRON)
	var shell: PackedVector2Array = InkPen.arc_pts(Vector2(-4, 22), 44.0, 40.0, PI, TAU, 22)
	pen.poly(shell, shell_col)
	pen.detail_path(InkPen.arc_pts(Vector2(-40, 22), 34.0, 34.0, -0.95, -0.05, 8), 2.4, Color(Palette.INK_LINE, 0.7))
	pen.detail_path(InkPen.arc_pts(Vector2(32, 22), 34.0, 34.0, PI + 0.05, PI + 0.95, 8), 2.4, Color(Palette.INK_LINE, 0.7))
	pen.detail(Vector2(-4, -16), Vector2(-4, 20), 2.4, Color(Palette.INK_LINE, 0.7))
	pen.box(-48, 18, 40, 26, skin)
	if not boss:
		pen.circle(Vector2(-10, -16), 6.0, Palette.MEADOW_LIGHT)
		pen.circle(Vector2(0, -18), 5.0, Palette.MEADOW_LIGHT)


static func _bubbler(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 28.0)
	var b: float = _bob(frame, 3.0)
	_feet(pen, [-12.0, 12.0], Palette.CREATURE_BUBBLE.darkened(0.25), frame, 9.0)
	# A bubble wand held up: the ring is open, so it reads as a ring.
	pen.stroke(Vector2(18, 4 + b), Vector2(26, -26 + b), 4.0, Palette.TIMBER)
	pen.path(_closed(InkPen.ellipse_pts(Vector2(28, -38 + b), 11.0, 11.0, 18)), 4.5, Palette.WOOD)
	pen.ellipse(Vector2(-2, 12 + b), 28.0, 23.0, Palette.CREATURE_BUBBLE)
	pen.ellipse(Vector2(20, 6 + b), 7.0, 6.0, Palette.CREATURE_BUBBLE)
	pen.eye(Vector2(-6, 2 + b), 6.0)
	pen.eye(Vector2(8, 2 + b), 5.5)
	pen.detail_path(_closed(InkPen.ellipse_pts(Vector2(2, 16 + b), 4.0, 3.5, 10)), 2.0, Palette.INK_LINE)
	pen.detail_path(_closed(InkPen.ellipse_pts(Vector2(16, -48 + b), 4.0, 4.0, 10)), 1.6, Palette.BUBBLE)
	pen.detail_path(_closed(InkPen.ellipse_pts(Vector2(8, -40 + b), 2.6, 2.6, 8)), 1.4, Palette.BUBBLE)


static func _puffball(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 32.0)
	var b: float = _bob(frame, 3.0)
	_feet(pen, [-14.0, 14.0], Palette.CREATURE_PUFF.darkened(0.25), frame, 8.0)
	pen.stroke(Vector2(0, -26 + b), Vector2(4, -42 + b), 3.0, Palette.ROOF_MOSS)
	pen.ellipse(Vector2(12, -44 + b), 9.0, 5.0, Palette.ROOF_MOSS)
	pen.poly(_scalloped(Vector2(0, 4 + b), 36.0, 32.0, 11, 0.12), Palette.CREATURE_PUFF)
	pen.detail_poly(InkPen.ellipse_pts(Vector2(-4, 14 + b), 20.0, 10.0, 14), Palette.CREATURE_PUFF.lightened(0.3))
	pen.detail_path(InkPen.arc_pts(Vector2(4, 0 + b), 5.0, 3.0, 0.2, PI - 0.2, 6), 2.4, Palette.INK_LINE)
	pen.detail_path(InkPen.arc_pts(Vector2(18, 0 + b), 5.0, 3.0, 0.2, PI - 0.2, 6), 2.4, Palette.INK_LINE)


static func _puff(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 20.0)
	var b: float = _bob(frame, 7.0)
	# A small round fluff with seven soft bumps and tiny feet: a Puffball's
	# child, without its sprout.
	_feet(pen, [-9.0, 9.0], Palette.CREATURE_PUFF.darkened(0.25), frame, 6.0)
	pen.poly(_scalloped(Vector2(0, 10 + b), 25.0, 23.0, 7, 0.16), Palette.CREATURE_PUFF)
	pen.detail_poly(InkPen.ellipse_pts(Vector2(-3, 18 + b), 12.0, 6.0, 12), Palette.CREATURE_PUFF.lightened(0.3))
	pen.eye(Vector2(-3, 6 + b), 5.0)
	pen.eye(Vector2(10, 6 + b), 4.6)


static func _mender(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 30.0)
	var b: float = _bob(frame, 3.0)
	_feet(pen, [-10.0, 10.0], Palette.CREATURE_MEND.darkened(0.25), frame, 8.0)
	# A leafy staff in front.
	pen.stroke(Vector2(38, 34), Vector2(40, -24 + b), 3.5, Palette.TIMBER)
	pen.ellipse(Vector2(34, -30 + b), 7.0, 4.0, Palette.ROOF_MOSS)
	pen.ellipse(Vector2(46, -32 + b), 7.0, 4.0, Palette.ROOF_MOSS)
	pen.poly(PackedVector2Array([Vector2(-16, -4 + b), Vector2(16, -4 + b), Vector2(18, 30), Vector2(-18, 30)]), Palette.CREATURE_MEND)
	pen.stroke(Vector2(14, 10 + b), Vector2(36, 6 + b), 4.0, Palette.CREATURE_MEND)
	pen.eye(Vector2(-3, 4 + b), 5.0)
	pen.eye(Vector2(9, 4 + b), 4.6)
	# The wide mushroom cap.
	var cap: PackedVector2Array = InkPen.arc_pts(Vector2(0, -6 + b), 38.0, 34.0, PI, TAU, 18)
	cap.append(Vector2(30, -2 + b))
	cap.append(Vector2(-30, -2 + b))
	pen.poly(cap, Palette.CREATURE_MEND_CAP)
	for spot: Vector2 in [Vector2(-16, -22), Vector2(4, -30), Vector2(20, -16)]:
		pen.detail_circle(spot + Vector2(0, b), 4.5, Palette.FLOUR)


static func _gatecrasher(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 42.0)
	var dark: Color = Palette.CREATURE_BRUTE.darkened(0.25)
	for i: int in 4:
		var x: float = -30.0 + float(i) * 17.0
		var lift: float = -4.0 if (i + frame) % 2 == 0 and frame % 2 == 1 else 0.0
		pen.box(x - 6.0, 18 + lift, x + 6.0, 34 + lift, dark)
	pen.poly(_fuzzy(Vector2(-8, 4), 36.0, 26.0, 22, 3.0), Palette.CREATURE_BRUTE)
	pen.circle(Vector2(28, 12), 16.0, Palette.CREATURE_BRUTE)
	pen.ellipse(Vector2(40, 18), 8.0, 6.0, Palette.CREATURE_BRUTE.lightened(0.2))
	pen.eye(Vector2(32, 6), 4.6)
	# Two big horns curving up from the head: a "U" above it.
	pen.path(PackedVector2Array([Vector2(32, -2), Vector2(42, -10), Vector2(46, -24), Vector2(42, -36)]), 7.0, Palette.BONE)
	pen.path(PackedVector2Array([Vector2(20, -2), Vector2(12, -14), Vector2(12, -28), Vector2(18, -38)]), 7.0, Palette.BONE)
	pen.detail(Vector2(-28, -14), Vector2(-14, -18), 2.0, dark)
	pen.detail(Vector2(-22, -6), Vector2(-6, -10), 2.0, dark)


static func _moth(pen: InkPen, frame: int, boss: bool) -> void:
	var col: Color = Palette.BOSS_MOON if boss else Palette.CREATURE_MOTH
	pen.shadow(Vector2(0, 42), 26.0)
	var spread: float = 1.0 if frame % 2 == 0 else 0.82
	for side: float in [-1.0, 1.0]:
		if boss:
			# Long tail streamers from the hind wings.
			pen.path(PackedVector2Array([Vector2(16 * side, 12), Vector2(26 * side, 26), Vector2(22 * side, 40), Vector2(30 * side, 48)]), 6.0, col.darkened(0.15))
		var fore: PackedVector2Array = PackedVector2Array([Vector2(5 * side, -20), Vector2(30 * side * spread, -40), Vector2(48 * side * spread, -32), Vector2(42 * side * spread, -6), Vector2(6 * side, -4)])
		var hind: PackedVector2Array = PackedVector2Array([Vector2(5 * side, -4), Vector2(36 * side * spread, 4), Vector2(30 * side * spread, 22), Vector2(10 * side, 16)])
		if side < 0.0:
			fore.reverse()
			hind.reverse()
		pen.poly(hind, col.darkened(0.12))
		pen.poly(fore, col)
		if boss:
			var c: Vector2 = Vector2(28 * side * spread, -22)
			pen.detail_poly(InkPen.arc_pts(c, 7.0, 7.0, PI * 0.3, PI * 1.7, 8), Palette.MOON)
		else:
			# Plated wings: the armor shows as ridge lines.
			pen.detail(Vector2(10 * side, -14), Vector2(40 * side * spread, -30), 2.0, Color(Palette.INK_LINE, 0.6))
			pen.detail(Vector2(10 * side, -9), Vector2(40 * side * spread, -12), 2.0, Color(Palette.INK_LINE, 0.6))
	pen.ellipse(Vector2(0, -2), 8.0, 20.0, col.darkened(0.3))
	pen.circle(Vector2(0, -24), 8.0, col.darkened(0.3))
	for side: float in [-1.0, 1.0]:
		pen.path(PackedVector2Array([Vector2(3 * side, -30), Vector2(10 * side, -42), Vector2(20 * side, -48)]), 3.0, col.darkened(0.3))
		for k: int in 3:
			var p: Vector2 = Vector2(3 * side, -30).lerp(Vector2(20 * side, -48), float(k + 1) / 4.0)
			pen.detail(p, p + Vector2(4 * side, 4), 1.6, col.darkened(0.3))
	pen.eye(Vector2(-4, -25), 3.2)
	pen.eye(Vector2(4, -25), 3.2)


static func _grumblesack(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(0, 37), 42.0)
	var b: float = _bob(frame, 3.0)
	_feet(pen, [-18.0, 18.0], Palette.BOSS_SACK.darkened(0.3), frame, 11.0)
	# A lumpy sack, wide below and tied at the neck.
	var body: PackedVector2Array = PackedVector2Array()
	for i: int in 28:
		var a: float = TAU * float(i) / 28.0
		var r: float = 1.0 + 0.05 * sin(a * 5.0)
		var p: Vector2 = Vector2(cos(a) * 42.0 * r, sin(a) * 32.0 * r)
		if p.y < 0.0:
			p.x *= 1.0 + p.y / 50.0
			p.y *= 1.35
		body.append(p + Vector2(0, 6 + b))
	pen.poly(body, Palette.BOSS_SACK)
	pen.poly(PackedVector2Array([Vector2(-8, -34 + b), Vector2(8, -34 + b), Vector2(18, -50 + b), Vector2(6, -44 + b), Vector2(0, -52 + b), Vector2(-6, -44 + b), Vector2(-18, -50 + b)]), Palette.BOSS_SACK.darkened(0.15))
	pen.box(-10, -38 + b, 10, -31 + b, Palette.TIMBER)
	pen.detail_poly(PackedVector2Array([Vector2(-30, 14 + b), Vector2(-16, 12 + b), Vector2(-17, 26 + b), Vector2(-31, 26 + b)]), Palette.BOSS_SACK.darkened(0.2))
	pen.eye(Vector2(2, -4 + b), 6.5)
	pen.eye(Vector2(20, -4 + b), 6.0)
	pen.detail(Vector2(-6, -16 + b), Vector2(8, -11 + b), 3.0, Palette.INK_LINE)
	pen.detail(Vector2(28, -16 + b), Vector2(15, -11 + b), 3.0, Palette.INK_LINE)
	pen.detail_path(InkPen.arc_pts(Vector2(12, 14 + b), 7.0, 4.0, PI + 0.4, TAU - 0.4, 6), 2.4, Palette.INK_LINE)


static func _old_tusk(pen: InkPen, frame: int) -> void:
	pen.shadow(Vector2(-4, 37), 46.0)
	var dark: Color = Palette.BOSS_TUSK.darkened(0.3)
	for i: int in 4:
		var x: float = -36.0 + float(i) * 18.0
		var lift: float = -4.0 if (i + frame) % 2 == 0 and frame % 2 == 1 else 0.0
		pen.box(x - 7.0, 16 + lift, x + 7.0, 34 + lift, dark)
	pen.poly(_fuzzy(Vector2(-12, 0), 38.0, 30.0, 26, 4.5), Palette.BOSS_TUSK)
	pen.poly(PackedVector2Array([Vector2(14, -12), Vector2(34, -6), Vector2(42, 12), Vector2(30, 20), Vector2(16, 16)]), Palette.BOSS_TUSK)
	pen.eye(Vector2(26, -2), 4.0)
	# Two long tusks curving up from the snout, clear of the head.
	for k: int in 2:
		var o: Vector2 = Vector2(-8.0 * float(k), 3.0 * float(k))
		var pts: PackedVector2Array = PackedVector2Array([Vector2(34, 16) + o, Vector2(44, 12) + o, Vector2(50, -2) + o, Vector2(47, -22) + o])
		pen.path(pts, 7.0 - float(k), Palette.BONE)
	pen.detail(Vector2(-38, -18), Vector2(-24, -26), 2.4, dark)
	pen.detail(Vector2(-22, -22), Vector2(-8, -28), 2.4, dark)


# Shape helpers.

static func _fuzzy(c: Vector2, rx: float, ry: float, n: int, depth: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var k: float = 1.0 if i % 2 == 0 else 1.0 - depth / maxf(rx, ry)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts


## An ellipse with `bumps` round bumps around it.
static func _scalloped(c: Vector2, rx: float, ry: float, bumps: int, depth: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = bumps * 6
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var k: float = 1.0 - depth + depth * absf(sin(a * float(bumps) * 0.5))
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return pts


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out
