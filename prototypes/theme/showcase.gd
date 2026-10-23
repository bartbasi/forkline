# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Draws the silhouette sheet and the store icon idea for docs/art.
## Prototype only.

const P := preload("res://prototypes/theme/palette.gd")
const Art := preload("res://prototypes/theme/art.gd")


static func draw_sheet(ci: CanvasItem, art: Art, bold: Font, body: Font, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), P.CARD)
	var pad: float = vs.x * 0.025
	var unit: float = vs.y / 100.0
	_label(ci, Rect2(pad, unit * 1.5, vs.x - 2.0 * pad, unit * 5.0), "Forkline theme slice: silhouettes at tier 1", int(unit * 3.6), P.TEXT_DARK, bold)
	_label(ci, Rect2(pad, unit * 6.5, vs.x - 2.0 * pad, unit * 3.0), "Each pair: in color, then in one flat color. Every tower and creature must read by shape alone.", int(unit * 2.0), P.TEXT_MUTED, body)
	var cell_w: float = (vs.x - 2.0 * pad) / 6.0
	# Towers.
	var band: Rect2 = Rect2(pad, unit * 11.0, vs.x - 2.0 * pad, unit * 25.0)
	_band(ci, band, P.MEADOW)
	var mono_band: Rect2 = Rect2(pad, unit * 41.0, vs.x - 2.0 * pad, unit * 20.0)
	var tower_size: float = minf(cell_w * 0.5, band.size.y / 2.5)
	art.ci = ci
	for i: int in 6:
		var x: float = pad + cell_w * (float(i) + 0.5)
		art.mono = false
		ci.draw_colored_polygon(Art.ellipse_pts(Vector2(x, band.end.y - unit * 3.0), tower_size * 0.6, tower_size * 0.28, 24), P.PAD)
		art.tower(i, Vector2(x, band.end.y - unit * 3.0), tower_size, -PI / 2.0, 0.0)
		_label(ci, Rect2(x - cell_w * 0.5, band.end.y + unit * 0.5, cell_w, unit * 2.6), Art.TOWER_NAMES[i], int(unit * 2.2), P.TEXT_DARK, bold)
		_label(ci, Rect2(x - cell_w * 0.5, band.end.y + unit * 2.8, cell_w, unit * 2.0), Art.TOWER_ROLES[i], int(unit * 1.7), P.TEXT_MUTED, body)
		art.mono = true
		art.mono_color = P.INK_LINE
		art.tower(i, Vector2(x, mono_band.end.y - unit * 1.0), tower_size * 0.8, -PI / 2.0, 0.0)
	art.mono = false
	# Creatures, the gate and the hearth hall.
	var road_band: Rect2 = Rect2(pad, unit * 64.0, vs.x - 2.0 * pad, unit * 14.0)
	_band(ci, road_band, P.ROAD)
	var mono_row: float = unit * 96.0
	var sizes: PackedFloat32Array = [1.0, 1.0, 1.24, 0.68]
	var creature_size: float = road_band.size.y * 0.5
	for i: int in 6:
		var x: float = pad + cell_w * (float(i) + 0.5)
		var feet: Vector2 = Vector2(x, road_band.end.y - unit * 2.5)
		var name: String = ""
		var role: String = ""
		for pass_mono: int in 2:
			art.mono = pass_mono == 1
			art.mono_color = P.INK_LINE
			var at: Vector2 = feet if pass_mono == 0 else Vector2(x, mono_row)
			if i < 4:
				art.t = 0.3
				if i == Art.Creature.SWARM:
					for k: int in 3:
						art.creature(i, at + Vector2(-0.3 + 0.3 * float(k), -0.12 * float(k % 2)) * cell_w, creature_size * sizes[i], false, float(k), false)
				else:
					art.creature(i, at, creature_size * sizes[i], false, 0.0, false)
				name = Art.CREATURE_NAMES[i]
				role = Art.CREATURE_ROLES[i]
			elif i == 4:
				art.lw = 4.0
				art.gate(at + Vector2(0, -unit * 0.5), Vector2.RIGHT, cell_w * 0.28, unit * 7.5, true, 0.0)
				art.lw = 3.0
				name = "Gate"
				role = "closes one road"
			else:
				art.hearth_hall(at, cell_w * 0.8)
				name = "Hearth hall"
				role = "the village you defend"
		_label(ci, Rect2(x - cell_w * 0.5, road_band.end.y + unit * 0.5, cell_w, unit * 2.6), name, int(unit * 2.2), P.TEXT_DARK, bold)
		_label(ci, Rect2(x - cell_w * 0.5, road_band.end.y + unit * 2.8, cell_w, unit * 2.0), role, int(unit * 1.7), P.TEXT_MUTED, body)
	art.mono = false


static func _band(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r.size.y * 0.08))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _label(ci: CanvasItem, r: Rect2, s: String, size: int, col: Color, font: Font) -> void:
	var fs: int = size
	while fs > 10 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x:
		fs -= 1
	var base: float = r.position.y + (r.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	ci.draw_string(font, Vector2(r.position.x, base), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


## The 512 x 512 store icon idea: a road that forks around a lantern-lit
## watch post, a gate closing one branch, night creatures on the other.
static func draw_icon(ci: CanvasItem, art: Art, vs: Vector2) -> void:
	var s: float = minf(vs.x, vs.y)
	var o: Vector2 = (vs - Vector2(s, s)) * 0.5
	art.ci = ci
	art.mono = false
	art.t = 0.4
	var sky: Array[Color] = [P.SKY_TOP, P.SKY_MID, P.SKY_LOW, P.SKY_GLOW]
	var stops: PackedFloat32Array = [0.0, 0.22, 0.36, 0.44]
	for i: int in 3:
		var y0: float = o.y + stops[i] * s
		var y1: float = o.y + stops[i + 1] * s
		ci.draw_polygon(PackedVector2Array([Vector2(o.x, y0), Vector2(o.x + s, y0), Vector2(o.x + s, y1), Vector2(o.x, y1)]),
			PackedColorArray([sky[i], sky[i], sky[i + 1], sky[i + 1]]))
	ci.draw_rect(Rect2(o.x, o.y + 0.44 * s, s, 0.56 * s), P.HILL_NEAR)
	for st: Vector2 in [Vector2(0.12, 0.08), Vector2(0.3, 0.16), Vector2(0.55, 0.06), Vector2(0.18, 0.27), Vector2(0.62, 0.2)]:
		art.star(o + st * s, 0.012 * s, P.STAR)
	art.glow(o + Vector2(0.84, 0.11) * s, 0.18 * s, P.MOON, 1.2)
	art.moon(o + Vector2(0.84, 0.11) * s, 0.065 * s)
	var hill: PackedVector2Array = PackedVector2Array([o + Vector2(0, 0.46) * s])
	for i: int in 21:
		var t: float = float(i) / 20.0
		hill.append(o + Vector2(t, 0.40 - 0.05 * sin(t * PI) + 0.012 * sin(t * 13.0)) * s)
	hill.append(o + Vector2(1.0, 1.0) * s)
	hill.append(o + Vector2(0.0, 1.0) * s)
	ci.draw_colored_polygon(hill, P.MEADOW)
	var trunk: PackedVector2Array = _curve([Vector2(0.5, 0.30), Vector2(0.5, 0.42), Vector2(0.5, 0.52)], o, s)
	var left: PackedVector2Array = _curve([Vector2(0.5, 0.52), Vector2(0.32, 0.66), Vector2(0.2, 0.84), Vector2(0.12, 1.06)], o, s)
	var right: PackedVector2Array = _curve([Vector2(0.5, 0.52), Vector2(0.68, 0.66), Vector2(0.8, 0.84), Vector2(0.88, 1.06)], o, s)
	for road: PackedVector2Array in [trunk, left, right]:
		_thick(ci, road, 0.125 * s, P.ROAD_EDGE)
	for road: PackedVector2Array in [trunk, left, right]:
		_thick(ci, road, 0.095 * s, P.ROAD)
	# Dashed route line down the open branch.
	var route: PackedVector2Array = trunk.duplicate()
	route.append_array(right)
	for i: int in range(2, route.size() - 3, 3):
		ci.draw_line(route[i], route[i + 1], P.INK_LINE, 0.022 * s, true)
		ci.draw_line(route[i], route[i + 1], P.ROUTE, 0.011 * s, true)
	art.thicket(o + Vector2(0.5, 0.33) * s, 0.42 * s, 0.0)
	art.lw = 0.006 * s
	art.gate(o + Vector2(0.285, 0.69) * s, Vector2(0.83, 0.55).normalized(), 0.075 * s, 0.11 * s, true, 0.0)
	art.lw = 3.0
	art.creature(Art.Creature.FAST, o + Vector2(0.53, 0.47) * s, 0.09 * s, false, 0.0, false)
	art.creature(Art.Creature.BASIC, o + Vector2(0.70, 0.70) * s, 0.12 * s, false, 1.0, false)
	art.creature(Art.Creature.BASIC, o + Vector2(0.83, 0.93) * s, 0.13 * s, false, 2.5, false)
	var post: Vector2 = o + Vector2(0.5, 0.985) * s
	var size: float = 0.27 * s
	art.tower(Art.Tower.WATCH, post, size, 0.0, 1.0)
	var from: Vector2 = post + Vector2(0.0, -1.03 * size)
	var to: Vector2 = o + Vector2(0.69, 0.66) * s
	ci.draw_line(from, to, Color(P.LANTERN, 0.35), 0.03 * s, true)
	ci.draw_line(from.lerp(to, 0.55), to, P.LANTERN_CORE, 0.012 * s, true)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + 0.3
		art.star(to + Vector2(cos(a), sin(a)) * 0.05 * s, 0.022 * s, P.SPARKLE if i % 2 == 0 else P.SPARKLE_LILAC)


static func _curve(ctrl: Array, o: Vector2, s: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = ctrl.size()
	for i: int in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k: int in 10:
			out.append(o + p1.cubic_interpolate(p2, p0, p3, float(k) / 10.0) * s)
	var last: Vector2 = ctrl[n - 1]
	out.append(o + last * s)
	return out


static func _thick(ci: CanvasItem, pts: PackedVector2Array, width: float, col: Color) -> void:
	ci.draw_polyline(pts, col, width, true)
	for p: Vector2 in pts:
		ci.draw_circle(p, width * 0.5, col, true, -1.0, true)
