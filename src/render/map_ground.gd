# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapGround
extends Node2D
## The static map: ground, scenery, roads, spots, sockets, the base and the entrance
## thickets, drawn once with MapArt into a texture and shown as one sprite
## (docs/ARCHITECTURE.md 9.3). It is drawn again only when the sharpness
## it needs changes, for example when a fold gives the map bigger cells. Internal to
## src/render/.

const CELL: float = 128.0
## Room around the map in the texture, in cells, for the entrance thickets.
const MARGIN: float = 0.75

## Draws the map into the viewport.
class Painter:
	extends Node2D
	var ground: MapGround

	func _draw() -> void:
		ground.paint(self)


var texel_scale: float = 1.0
## How many times the picture was queued for drawing.
var bakes: int = 0

var _grid: PackedStringArray = PackedStringArray()
var _viewport: SubViewport
var _painter: Painter
var _sprite: Sprite2D
var _draws: int = 0


func setup(grid: PackedStringArray, material: Material) -> void:
	_grid = grid
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_painter = Painter.new()
	_painter.ground = self
	_viewport.add_child(_painter)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.material = material
	_sprite.position = Vector2(-MARGIN, -MARGIN) * CELL
	_sprite.texture = _viewport.get_texture()
	add_child(_sprite)
	bake(1.0)


## Queues one draw at `scale` texels per local pixel.
func bake(scale: float) -> void:
	texel_scale = maxf(scale, 0.25)
	var cols: float = float(Sim.MAP_COLUMNS) + 2.0 * MARGIN
	var rows: float = float(_grid.size()) + 2.0 * MARGIN
	_viewport.size = Vector2i(ceili(cols * CELL * texel_scale), ceili(rows * CELL * texel_scale))
	_painter.position = Vector2(MARGIN, MARGIN) * CELL * texel_scale
	_painter.scale = Vector2(texel_scale, texel_scale)
	_sprite.scale = Vector2.ONE / texel_scale
	bakes += 1
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Called by the painter, inside its _draw().
func paint(canvas: CanvasItem) -> void:
	_draws += 1
	MapArt.draw_ground(canvas, _grid, CELL, UiTheme.font(UiTheme.WEIGHT_BOLD))


## How many times the map was really drawn (not just queued).
func draw_count() -> int:
	return _draws
