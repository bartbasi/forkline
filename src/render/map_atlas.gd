# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapAtlas
extends SubViewport
## One sheet of pictures for every tower look, every creature frame and the status
## marks, drawn once with Silhouettes into this viewport's texture (docs/ARCHITECTURE.md
## 9.3). Every sprite on the map is then a region of this one texture, so the
## Compatibility renderer batches them into very few draw calls, and nothing runs
## Silhouettes code while a wave is playing.
##
## Sizes in an Entry are in map local pixels (a cell is MapView.CELL). The sheet is
## drawn at `texel_scale` texels per local pixel, so the sprites stay sharp on the
## screen they are shown on. Internal to src/render/.

const CELL: float = 128.0
const WIDTH: int = 2048
const PAD: int = 2
## Tower tile, as fractions of a cell: the building reaches 0.86 up and 0.42 down.
const TOWER_TILE: Vector2 = Vector2(1.12, 1.36)
const TOWER_CENTER: Vector2 = Vector2(0.56, 0.90)
## A creature tile is its box times this, so the outline has room.
const ENEMY_TILE: float = 1.26
const BUBBLE_TILE: float = 1.1
const DROWSY_TILE: Vector2 = Vector2(0.7, 0.6)
const DROWSY_ANCHOR: Vector2 = Vector2(0.1, 0.95)
const BOOST_TILE: float = 1.1

const GATE_TILE: float = 1.3
const HEART_TILE: float = 1.0

enum Kind { TOWER, ENEMY, DROWSY, BUBBLE, BOOST, GATE, HEART }


## One picture on the sheet.
class Entry:
	extends RefCounted
	var key: String = ""
	var kind: int = 0
	var type: StringName = &""
	var tier: int = 1
	var spec: int = -1
	var frame: int = 0
	## Tile size, the drawing center and the ground or feet point, in local pixels.
	var tile: Vector2 = Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	var anchor: Vector2 = Vector2.ZERO
	## Where the tile sits on the sheet, in texels.
	var rect: Rect2 = Rect2()


## Draws the entries. Counts its draws so tests can see the sheet is not redrawn.
class Painter:
	extends Node2D
	var atlas: MapAtlas

	func _draw() -> void:
		atlas.paint(self)


var texel_scale: float = 1.0
var entries: Array[Entry] = []
## How many times the sheet was laid out and queued for drawing.
var bakes: int = 0
## Frame rects per creature type, four each, for the per frame lookups.
var enemy_rects: Dictionary[StringName, Array] = {}

var _index: Dictionary[String, int] = {}
var _painter: Painter
var _draws: int = 0


func _init() -> void:
	transparent_bg = true
	disable_3d = true
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	size = Vector2i(WIDTH, 64)
	_painter = Painter.new()
	_painter.atlas = self
	add_child(_painter)


static func tower_key(type: StringName, tier: int, spec: int) -> String:
	var t: int = clampi(tier, 1, 3)
	return "t:%s:%d:%d" % [type, t, spec if t == 3 else -1]


static func enemy_key(type: StringName, frame: int) -> String:
	return "e:%s:%d" % [type, frame]


func has_key(key: String) -> bool:
	return _index.has(key)


func entry_for(key: String) -> Entry:
	if not _index.has(key):
		return null
	return entries[_index[key]]


func add_tower(type: StringName, tier: int, spec: int) -> void:
	var key: String = tower_key(type, tier, spec)
	if _index.has(key):
		return
	var e: Entry = Entry.new()
	e.key = key
	e.kind = Kind.TOWER
	e.type = type
	e.tier = clampi(tier, 1, 3)
	e.spec = spec if e.tier == 3 else -1
	e.tile = TOWER_TILE * CELL
	e.center = TOWER_CENTER * CELL
	e.anchor = e.center + Vector2(0.0, Silhouettes.TOWER_GROUND * CELL)
	_add(e)


## Every look of one tower: tier 1, tier 2 and both tier 3 paths.
func add_tower_looks(type: StringName) -> void:
	add_tower(type, 1, -1)
	add_tower(type, 2, -1)
	add_tower(type, 3, 0)
	add_tower(type, 3, 1)


func add_enemy(type: StringName) -> void:
	if enemy_rects.has(type):
		return
	var box: float = Silhouettes.enemy_size(type, CELL)
	var side: float = box * ENEMY_TILE
	for frame: int in 4:
		var e: Entry = Entry.new()
		e.key = enemy_key(type, frame)
		e.kind = Kind.ENEMY
		e.type = type
		e.frame = frame
		e.tile = Vector2(side, side)
		e.center = e.tile * 0.5
		e.anchor = e.center + Vector2(0.0, Silhouettes.FEET * box)
		_add(e)
	enemy_rects[type] = [Rect2(), Rect2(), Rect2(), Rect2()]


## The status marks: the drowsy "z z" (four frames), the bubble ring, the boost chevrons and
## the heart that floats up from the home when a creature gets through.
func add_marks() -> void:
	if _index.has("m:bubble"):
		return
	for frame: int in 4:
		var d: Entry = Entry.new()
		d.key = "m:drowsy:%d" % frame
		d.kind = Kind.DROWSY
		d.frame = frame
		d.tile = DROWSY_TILE * CELL
		d.center = DROWSY_ANCHOR * CELL
		d.anchor = d.center
		_add(d)
	var b: Entry = Entry.new()
	b.key = "m:bubble"
	b.kind = Kind.BUBBLE
	b.tile = Vector2(BUBBLE_TILE, BUBBLE_TILE) * CELL
	b.center = b.tile * 0.5
	b.anchor = b.center
	_add(b)
	var x: Entry = Entry.new()
	x.key = "m:boost"
	x.kind = Kind.BOOST
	x.tile = Vector2(BOOST_TILE, BOOST_TILE) * CELL
	x.center = x.tile * 0.5
	x.anchor = x.center
	_add(x)
	var h: Entry = Entry.new()
	h.key = "m:heart"
	h.kind = Kind.HEART
	h.tile = Vector2(HEART_TILE, HEART_TILE) * CELL
	h.center = h.tile * 0.5
	h.anchor = h.center
	_add(h)


## Every look of a gate on a road that runs across or up and down the screen.
func add_gates() -> void:
	if _index.has(gate_key(0, false)):
		return
	for look: int in MapArt.Gate.size():
		for across: bool in [false, true]:
			var g: Entry = Entry.new()
			g.key = gate_key(look, across)
			g.kind = Kind.GATE
			g.tier = look
			g.frame = 1 if across else 0
			g.tile = Vector2(GATE_TILE, GATE_TILE) * CELL
			g.center = g.tile * 0.5
			g.anchor = g.center
			_add(g)


static func gate_key(look: int, across: bool) -> String:
	return "g:%d:%d" % [look, 1 if across else 0]


## Lays the sheet out at `scale` texels per local pixel and queues one draw.
func bake(scale: float) -> void:
	texel_scale = maxf(scale, 0.25)
	var x: int = PAD
	var y: int = PAD
	var row_h: int = 0
	for e: Entry in entries:
		var w: int = ceili(e.tile.x * texel_scale)
		var h: int = ceili(e.tile.y * texel_scale)
		if x + w + PAD > WIDTH:
			x = PAD
			y += row_h + PAD
			row_h = 0
		e.rect = Rect2(float(x), float(y), float(w), float(h))
		x += w + PAD
		row_h = maxi(row_h, h)
	size = Vector2i(WIDTH, maxi(y + row_h + PAD, 8))
	for type: StringName in enemy_rects:
		var rects: Array = enemy_rects[type]
		for frame: int in 4:
			rects[frame] = entries[_index[enemy_key(type, frame)]].rect
	bakes += 1
	_painter.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Called by the painter, inside its _draw().
func paint(canvas: CanvasItem) -> void:
	_draws += 1
	for e: Entry in entries:
		var at: Vector2 = e.rect.position + e.center * texel_scale
		match e.kind:
			Kind.TOWER:
				Silhouettes.draw_tower(canvas, e.type, e.tier, e.spec, at, CELL * texel_scale)
			Kind.ENEMY:
				Silhouettes.draw_enemy(canvas, e.type, at, Silhouettes.enemy_size(e.type, CELL) * texel_scale, e.frame)
			Kind.DROWSY:
				Silhouettes.draw_drowsy(canvas, at, CELL * texel_scale, e.frame)
			Kind.BUBBLE:
				Silhouettes.draw_bubble(canvas, at, CELL * texel_scale)
			Kind.BOOST:
				Silhouettes.draw_boost(canvas, at, CELL * texel_scale)
			Kind.HEART:
				Silhouettes.draw_glyph(canvas, &"heart", at, CELL * texel_scale * 0.92)
			Kind.GATE:
				MapArt.draw_gate_at(canvas, at, CELL * texel_scale, e.frame == 1, e.tier as MapArt.Gate)


## How many times the sheet's pictures were really drawn (not just queued).
func draw_count() -> int:
	return _draws


func _add(e: Entry) -> void:
	_index[e.key] = entries.size()
	entries.append(e)
