# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapSparkles
extends Node2D
## Sparkle bursts from a pool of one-shot CPUParticles2D (docs/ARCHITECTURE.md 9.1, 9.3).
## At most EMITTERS emitters of PER_BURST particles each, so at most 384 particles are alive.
## A burst past the pool restarts the oldest emitter. The sparkle picture is a four point
## star made in code. Nothing here looks like a creature and nothing is red. Internal to
## src/render/.

const EMITTERS: int = 24
const PER_BURST: int = 16
const TEXTURE_SIZE: int = 32

enum Kind { DEFEAT, BUBBLE, BUILD, DUST }

var bursts: int = 0

var _pool: Array[CPUParticles2D] = []
var _next: int = 0
var _texture: ImageTexture
var _ramps: Array[Gradient] = []


func _init() -> void:
	_texture = _make_texture()
	_ramps = [
		_ramp(Palette.SPARKLE, Palette.SPARKLE_LILAC),
		_ramp(Palette.BUBBLE, Palette.SPARKLE),
		_ramp(Palette.LANTERN, Palette.LANTERN_CORE),
		_ramp(Palette.SMOKE, Palette.PLASTER),
	]
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	for i: int in EMITTERS:
		var p: CPUParticles2D = CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = PER_BURST
		p.explosiveness = 0.9
		p.lifetime_randomness = 0.3
		p.local_coords = true
		p.texture = _texture
		p.direction = Vector2(0.0, -1.0)
		p.spread = 180.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 6.0
		p.angle_min = -40.0
		p.angle_max = 40.0
		p.angular_velocity_min = -180.0
		p.angular_velocity_max = 180.0
		p.color_ramp = fade
		_pool.append(p)
		add_child(p)


## How many particles can be alive at once.
func particle_budget() -> int:
	return EMITTERS * PER_BURST


func emitter_count() -> int:
	return _pool.size()


## How many emitters are running now.
func active_count() -> int:
	var n: int = 0
	for p: CPUParticles2D in _pool:
		if p.emitting:
			n += 1
	return n


## A burst at `at`, in map pixels. `strength` 1.0 is a full defeat burst.
func burst(at: Vector2, kind: Kind, strength: float = 1.0) -> void:
	var p: CPUParticles2D = _pool[_next]
	_next = (_next + 1) % EMITTERS
	bursts += 1
	var s: float = clampf(strength, 0.3, 1.5)
	p.position = at
	p.color_initial_ramp = _ramps[kind]
	match kind:
		Kind.DEFEAT:
			p.lifetime = 0.75
			p.initial_velocity_min = 70.0 * s
			p.initial_velocity_max = 170.0 * s
			p.gravity = Vector2(0.0, -30.0)
			p.scale_amount_min = 0.45
			p.scale_amount_max = 0.85
		Kind.BUBBLE:
			p.lifetime = 0.5
			p.initial_velocity_min = 80.0 * s
			p.initial_velocity_max = 110.0 * s
			p.gravity = Vector2(0.0, -10.0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
		Kind.BUILD:
			p.lifetime = 0.7
			p.initial_velocity_min = 40.0 * s
			p.initial_velocity_max = 110.0 * s
			p.gravity = Vector2(0.0, -60.0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.6
		_:
			p.lifetime = 0.5
			p.initial_velocity_min = 30.0 * s
			p.initial_velocity_max = 80.0 * s
			p.gravity = Vector2(0.0, -20.0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.5
	p.restart()
	p.emitting = true


static func _ramp(a: Color, b: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([a, b])
	return g


## A white four point star with a soft core, 32 by 32.
static func _make_texture() -> ImageTexture:
	var img: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = float(TEXTURE_SIZE) * 0.5
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var dx: float = absf((float(x) + 0.5 - half) / half)
			var dy: float = absf((float(y) + 0.5 - half) / half)
			var star: float = pow(dx, 0.6667) + pow(dy, 0.6667)
			var a: float = clampf((1.0 - star) * 3.0, 0.0, 1.0)
			var glow: float = clampf(1.0 - sqrt(dx * dx + dy * dy) * 1.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(a, glow * 0.7)))
	return ImageTexture.create_from_image(img)
