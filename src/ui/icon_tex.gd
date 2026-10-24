# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name IconTex
extends RefCounted
## Small white icons for buttons, drawn in code (no image files). A button tints
## them with its icon colors. Kinds: cup, gear, back, lock, check, arrow, close,
## pause, play.

const SAMPLES: int = 3

static var _cache: Dictionary[String, ImageTexture] = {}


## The icon `kind` as a square texture of `px` pixels. Cached.
static func make(kind: StringName, px: int) -> ImageTexture:
	var key: String = "%s:%d" % [kind, px]
	if _cache.has(key):
		return _cache[key]
	var image: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var inside_count: float = float(SAMPLES * SAMPLES)
	for y: int in px:
		for x: int in px:
			var hits: int = 0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					var u: float = (float(x) + (float(sx) + 0.5) / float(SAMPLES)) / float(px)
					var v: float = (float(y) + (float(sy) + 0.5) / float(SAMPLES)) / float(px)
					if _inside(kind, u, v):
						hits += 1
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / inside_count))
	var tex: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


## Is the point (u, v) of the unit square inside the icon?
static func _inside(kind: StringName, u: float, v: float) -> bool:
	match kind:
		&"cup":
			return _cup(u, v)
		&"gear":
			return _gear(u, v)
		&"back":
			return _back(u, v)
		&"lock":
			return _lock(u, v)
		&"check":
			return _check(u, v)
		&"arrow":
			return _arrow(u, v)
		&"close":
			return _close(u, v)
		&"pause":
			return _pause(u, v)
		&"play":
			return _play(u, v)
	return false


static func _cup(u: float, v: float) -> bool:
	# The cup: a tapering body with a round bottom, a handle, a saucer and steam.
	var half: float = 0.27 - 0.07 * (v - 0.34) / 0.46
	if v >= 0.34 and v <= 0.80 and absf(u - 0.40) <= half:
		if v <= 0.68:
			return true
		var dx: float = (u - 0.40) / half
		var dy: float = (v - 0.68) / 0.12
		if dx * dx + dy * dy <= 1.0:
			return true
	var handle: float = Vector2(u, v).distance_to(Vector2(0.70, 0.50))
	if u > 0.62 and handle <= 0.17 and handle >= 0.085:
		return true
	if v >= 0.84 and v <= 0.92 and u >= 0.06 and u <= 0.74:
		return true
	if v >= 0.08 and v <= 0.26 and (absf(u - 0.30) <= 0.025 or absf(u - 0.50) <= 0.025):
		return true
	return false


static func _gear(u: float, v: float) -> bool:
	var d: Vector2 = Vector2(u - 0.5, v - 0.5)
	var r: float = d.length()
	if r < 0.14:
		return false
	if r <= 0.33:
		return true
	if r <= 0.47:
		var step: float = TAU / 8.0
		var a: float = fposmod(d.angle() + step * 0.5, step) - step * 0.5
		return absf(a) <= 0.20
	return false


static func _back(u: float, v: float) -> bool:
	var p: Vector2 = Vector2(u, v)
	var top: Vector2 = Vector2(0.64, 0.20)
	var mid: Vector2 = Vector2(0.34, 0.50)
	var bottom: Vector2 = Vector2(0.64, 0.80)
	return _near_segment(p, top, mid, 0.075) or _near_segment(p, mid, bottom, 0.075)


static func _lock(u: float, v: float) -> bool:
	var keyhole: float = Vector2(u, v).distance_to(Vector2(0.5, 0.64))
	if keyhole <= 0.07:
		return false
	if v >= 0.46 and v <= 0.90 and u >= 0.2 and u <= 0.8:
		return true
	var ring: float = Vector2(u, v).distance_to(Vector2(0.5, 0.40))
	return v < 0.46 and ring <= 0.25 and ring >= 0.13


static func _check(u: float, v: float) -> bool:
	var p: Vector2 = Vector2(u, v)
	var a: Vector2 = Vector2(0.20, 0.54)
	var b: Vector2 = Vector2(0.42, 0.76)
	var c: Vector2 = Vector2(0.82, 0.28)
	return _near_segment(p, a, b, 0.075) or _near_segment(p, b, c, 0.075)


## A right pointing arrow: a shaft and an open head.
static func _arrow(u: float, v: float) -> bool:
	var p: Vector2 = Vector2(u, v)
	var tip: Vector2 = Vector2(0.86, 0.5)
	return _near_segment(p, Vector2(0.10, 0.5), tip, 0.065) 		or _near_segment(p, Vector2(0.56, 0.22), tip, 0.065) 		or _near_segment(p, Vector2(0.56, 0.78), tip, 0.065)


static func _close(u: float, v: float) -> bool:
	var p: Vector2 = Vector2(u, v)
	return _near_segment(p, Vector2(0.26, 0.26), Vector2(0.74, 0.74), 0.07) 		or _near_segment(p, Vector2(0.74, 0.26), Vector2(0.26, 0.74), 0.07)


static func _pause(u: float, v: float) -> bool:
	if v < 0.22 or v > 0.78:
		return false
	return (u >= 0.27 and u <= 0.43) or (u >= 0.57 and u <= 0.73)


## A triangle pointing right.
static func _play(u: float, v: float) -> bool:
	if u < 0.30 or u > 0.80:
		return false
	var half: float = 0.30 * (0.80 - u) / 0.50
	return absf(v - 0.5) <= half


static func _near_segment(p: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) <= radius
