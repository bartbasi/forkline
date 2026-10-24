# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapStatus
extends Node2D
## Health bars for hurt creatures, the drowsy and bubble marks, and the boost marks, in one
## overlay (docs/ARCHITECTURE.md 9.3). The marks are regions of the MapAtlas texture. The
## overlay is redrawn only while something needs it. Internal to src/render/.

const CELL: float = 128.0


## What to draw for one creature this frame.
class Item:
	extends RefCounted
	var center: Vector2 = Vector2.ZERO
	var size: float = 0.0
	var hp: float = 1.0
	var bar: bool = false
	var drowsy: bool = false
	var bubble: bool = false
	var frame: int = 0


var items: Array[Item] = []
var boosted: Array[Vector2] = []
var atlas: MapAtlas
var _drawn_last: bool = false


## Replaces the lists. Redraws while they are not empty, and once more when they empty.
func set_items(new_items: Array[Item], new_boosted: Array[Vector2]) -> void:
	items = new_items
	boosted = new_boosted
	var busy: bool = not items.is_empty() or not boosted.is_empty()
	if busy or _drawn_last:
		queue_redraw()
	_drawn_last = busy


func _draw() -> void:
	if atlas == null:
		return
	var tex: Texture2D = atlas.get_texture()
	var bubble: MapAtlas.Entry = atlas.entry_for("m:bubble")
	var boost: MapAtlas.Entry = atlas.entry_for("m:boost")
	var drowsy: Array[MapAtlas.Entry] = []
	for f: int in 4:
		drowsy.append(atlas.entry_for("m:drowsy:%d" % f))
	# Textured marks first, then the bars: one texture in a row batches into one draw call.
	for it: Item in items:
		var k: float = it.size / CELL
		if it.bubble and bubble != null:
			draw_texture_rect_region(tex, Rect2(it.center - bubble.anchor * k, bubble.tile * k), bubble.rect)
		if it.drowsy:
			var d: MapAtlas.Entry = drowsy[it.frame & 3]
			if d != null:
				draw_texture_rect_region(tex, Rect2(it.center - d.anchor * k, d.tile * k), d.rect)
	if boost != null:
		for b: Vector2 in boosted:
			draw_texture_rect_region(tex, Rect2(b - boost.anchor, boost.tile), boost.rect)
	for it: Item in items:
		if it.bar:
			var w: float = maxf(it.size * 0.7, CELL * 0.3)
			var h: float = maxf(it.size * 0.09, 5.0)
			var bar: Rect2 = Rect2(it.center.x - w * 0.5, it.center.y - it.size * 0.62, w, h)
			draw_rect(bar.grow(3.0), Palette.INK_LINE)
			draw_rect(bar, Palette.HP_BACK)
			draw_rect(Rect2(bar.position, Vector2(w * clampf(it.hp, 0.0, 1.0), h)), Palette.HP_FILL)
