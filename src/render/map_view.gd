# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapView
extends Node2D
## Draws one Battle: the static map, towers, creatures, projectiles, sparkles, health bars,
## route lines, gates, range, selection and hint (docs/ARCHITECTURE.md 3.7, 9.3).
##
## It reads the Battle and never changes it. The map is drawn once into a texture. Every
## tower look and creature frame is drawn once into one sheet (MapAtlas), so a tower or a
## creature is one Sprite2D that only moves, and the Compatibility renderer batches them.
## Nodes are pooled. The local space is CELL pixels a cell, and fit() scales the node.
##
## Effects run on game time while a wave plays (so pause and 3x just work) and on real time
## in the build phase, so a shot in flight never hangs after the last creature is gone.

const CELL: float = 128.0
## Sub-units of the sim to local pixels.
const PX_PER_SUB: float = CELL / float(Sim.UNIT)
const WALK_FPS: float = 8.0
const FLAP_FPS: float = 11.0
const FINGER_CELLS: float = 0.45
const REFUSED_MS: int = 1500
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Draw order: ground, routes, gates, marks, then towers and creatures sorted by row, then shots,
## status and sparkles on top.
const Z_FLYER: int = 1
const Z_SHOTS: int = 2
const Z_STATUS: int = 3
const Z_SPARKLES: int = 4
const Z_LEAKS: int = 5


class TowerView:
	extends RefCounted
	var cell: Vector2i = Vector2i.ZERO
	var type: StringName = &""
	var tier: int = 0
	var spec: int = -2
	var sprite: Sprite2D
	var born_t: float = -10.0
	var kick_t: float = -10.0
	var gen: int = 0
	var at_rest: bool = true


class CreatureView:
	extends RefCounted
	var id: int = -1
	var type: StringName = &""
	var sprite: Sprite2D
	var size_px: float = 0.0
	var feet: float = 0.0
	var flyer: bool = false
	var boss: bool = false
	var center: Vector2 = Vector2.ZERO
	var left: bool = false
	var frame: int = -1
	var gen: int = 0
	var pop_t: float = 0.0
	var bubble_hold: float = -1.0
	var item: MapStatus.Item = MapStatus.Item.new()


var battle: Battle
var level: LevelData
## Microseconds the last sync() and play_events() took, for PerfProbe.
var last_sync_usec: int = 0
var last_events_usec: int = 0

var _atlas: MapAtlas
var _ground: MapGround
var _routes: MapRoutes
var _gates: MapGates
var _marks: MapMarks
var _entities: Node2D
var _shots: MapShots
var _status: MapStatus
var _sparkles: MapSparkles
var _leaks: MapLeaks
var _premult: CanvasItemMaterial

var _towers: Dictionary[Vector2i, TowerView] = {}
var _creatures: Dictionary[int, CreatureView] = {}
var _gone: Dictionary[int, CreatureView] = {}
var _dying: Array[CreatureView] = []
var _pool: Array[Sprite2D] = []
var _status_items: Array[MapStatus.Item] = []

var _turn: PackedInt32Array = PackedInt32Array()
var _bake_scale: float = 1.0
var _gen: int = 0
var _first_sync: bool = true
var _fx_time: float = 0.0
var _last_game: float = -1.0
var _last_real_us: int = 0
var _real_dt: float = 0.0
var _syncs: int = 0
var _has_boost: bool = false
var _boosted: Array[Vector2] = []
var _refused_cell: Vector2i = Vector2i(-1, -1)
var _refused_until: int = 0
var _arrival_ids: Dictionary[int, float] = {}
var _arrival_pos: Array[Vector2] = []
var _arrival_time: Array[float] = []


func _enter_tree() -> void:
	if _atlas != null:
		_refresh_bake()


# Setup and layout.

## Builds the static map layer and the sprite sheet for this battle. Calling it again
## starts over.
func setup(new_battle: Battle) -> void:
	_clear()
	battle = new_battle
	level = battle.level
	_premult = CanvasItemMaterial.new()
	_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_ground = MapGround.new()
	add_child(_ground)
	_ground.setup(level.grid, _premult)
	_routes = MapRoutes.new()
	add_child(_routes)
	_gates = MapGates.new()
	_gates.grid = level.grid
	_gates.material = _premult
	add_child(_gates)
	_marks = MapMarks.new()
	add_child(_marks)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_atlas = MapAtlas.new()
	add_child(_atlas)
	_shots = MapShots.new()
	_shots.z_index = Z_SHOTS
	add_child(_shots)
	_status = MapStatus.new()
	_status.z_index = Z_STATUS
	_status.atlas = _atlas
	_status.material = _premult
	add_child(_status)
	_sparkles = MapSparkles.new()
	_sparkles.z_index = Z_SPARKLES
	add_child(_sparkles)
	_leaks = MapLeaks.new()
	_leaks.z_index = Z_LEAKS
	_leaks.atlas = _atlas
	_leaks.material = _premult
	add_child(_leaks)
	_has_boost = false
	for id: StringName in level.towers:
		_atlas.add_tower_looks(id)
		var type: TowerType = battle.catalog.tower(id)
		if type != null and type.kind == &"boost":
			_has_boost = true
	for id: StringName in _level_enemy_types():
		_atlas.add_enemy(id)
	_atlas.add_marks()
	_atlas.add_gates()
	_gates.atlas = _atlas
	_build_turns()
	_bake_scale = 1.0
	_atlas.bake(_bake_scale)
	_refresh_bake()
	_first_sync = true
	_fx_time = 0.0
	_last_game = -1.0
	_last_real_us = 0


## Puts the map inside `rect` (the parent's coordinates), as large as fits, centered.
func fit(rect: Rect2) -> void:
	if level == null:
		return
	var map_size: Vector2 = Vector2(float(Sim.MAP_COLUMNS), float(level.rows)) * CELL
	var k: float = minf(rect.size.x / map_size.x, rect.size.y / map_size.y)
	if k <= 0.0:
		return
	scale = Vector2(k, k)
	position = rect.position + (rect.size - map_size * k) * 0.5
	_refresh_bake()


## A global canvas position to a cell; (-1, -1) outside the map.
func cell_at(global_point: Vector2) -> Vector2i:
	if level == null:
		return Vector2i(-1, -1)
	var p: Vector2 = get_global_transform().affine_inverse() * global_point
	var c: Vector2i = Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if c.x < 0 or c.y < 0 or c.x >= Sim.MAP_COLUMNS or c.y >= level.rows:
		return Vector2i(-1, -1)
	return c


## The nearest creature within reach of a finger; -1 for none.
func enemy_at(global_point: Vector2) -> int:
	var p: Vector2 = get_global_transform().affine_inverse() * global_point
	var best: int = -1
	var best_d: float = INF
	for id: int in _creatures:
		var v: CreatureView = _creatures[id]
		var reach: float = FINGER_CELLS * CELL + v.size_px * 0.25
		var d: float = v.center.distance_to(p)
		if d <= reach and d < best_d:
			best_d = d
			best = id
	return best


# Each frame.

## Adds, moves and frees entity nodes from the battle state. `alpha` is how far the game
## is between the last tick and the next, 0 to 1.
func sync(alpha: float) -> void:
	if battle == null:
		return
	var t0: int = Time.get_ticks_usec()
	_advance_clock(alpha)
	_gen += 1
	_syncs += 1
	_release_unclaimed()
	_sync_towers()
	_sync_creatures(clampf(alpha, 0.0, 1.0))
	_finish_dying()
	_sync_gates()
	_sync_layers()
	_first_sync = false
	last_sync_usec = Time.get_ticks_usec() - t0


## Projectiles, hit flashes, pops into sparkles, gate and building effects.
func play_events(events: Array[Dictionary]) -> void:
	if battle == null:
		return
	var t0: int = Time.get_ticks_usec()
	_arrival_ids.clear()
	_arrival_pos.clear()
	_arrival_time.clear()
	for e: Dictionary in events:
		if e.get("kind") == &"fired":
			_on_fired(e)
	for e: Dictionary in events:
		match e.get("kind"):
			&"popped":
				_on_popped(int(e["id"]))
			&"defeated":
				_on_defeated(int(e["id"]), Vector2(e["pos"] as Vector2i))
			&"leaked":
				_on_leaked(e)
			&"built", &"upgraded":
				_sparkles.burst(_ground_px(e["cell"] as Vector2i), MapSparkles.Kind.BUILD, 0.8)
			&"sold":
				_sparkles.burst(_ground_px(e["cell"] as Vector2i), MapSparkles.Kind.DUST, 0.8)
			&"gate_placed":
				_sparkles.burst(_center_px(e["cell"] as Vector2i), MapSparkles.Kind.DUST, 0.7)
			&"gate_broken":
				_sparkles.burst(_center_px(e["cell"] as Vector2i), MapSparkles.Kind.DUST, 1.5)
	last_events_usec = Time.get_ticks_usec() - t0


## Battle.routes() entries; [] hides the lines.
func show_routes(routes: Array[Dictionary]) -> void:
	if _routes != null:
		_routes.set_routes(routes, level)


## The crossed out gate on that socket for 1.5 s (RULES 7.4).
func show_refused(cell: Vector2i) -> void:
	_refused_cell = cell
	_refused_until = Time.get_ticks_msec() + REFUSED_MS


## `reach` in hundredths of a tile. With `boost`, also marks the towers a Bakery there would
## boost. (-1, -1) hides it.
func show_range(cell: Vector2i, reach: int, boost: bool) -> void:
	if _marks == null:
		return
	_marks.range_cell = cell
	_marks.range_radius = float(reach) / 100.0 * CELL if cell.x >= 0 else 0.0
	_marks.boost_cells.clear()
	if boost and cell.x >= 0 and battle != null:
		for t: TowerState in battle.towers:
			var type: TowerType = battle.catalog.tower(t.type)
			if t.cell != cell and type != null and type.kind == &"attack" and Vector2(t.cell - cell).length() * 100.0 <= float(reach):
				_marks.boost_cells.append(t.cell)
	_marks.queue_redraw()


func show_selection(cell: Vector2i) -> void:
	if _marks != null:
		_marks.selection = cell
		_marks.queue_redraw()


func show_hint(cell: Vector2i) -> void:
	if _marks != null:
		_marks.hint = cell
		_marks.queue_redraw()


# For tests and tools.

func creature_count() -> int:
	return _creatures.size()


## Creatures kept on screen for a moment after the sim removed them (a shot still flying).
func ghost_count() -> int:
	return _gone.size() + _dying.size()


func tower_count() -> int:
	return _towers.size()


func projectile_count() -> int:
	return _shots.shots.size() if _shots != null else 0


func ground_bakes() -> int:
	return _ground.bakes if _ground != null else 0


func ground_draws() -> int:
	return _ground.draw_count() if _ground != null else 0


func atlas_bakes() -> int:
	return _atlas.bakes if _atlas != null else 0


func sparkles() -> MapSparkles:
	return _sparkles


## The hearts that float up from the home when creatures get through.
func leaks() -> MapLeaks:
	return _leaks


## Entity sprites ever made, in use or pooled. It stops growing at the peak.
func sprite_count() -> int:
	return _entities.get_child_count() if _entities != null else 0


func bake_scale() -> float:
	return _bake_scale


func is_effect_busy() -> bool:
	return ghost_count() > 0 or (_shots != null and _shots.is_busy()) or (_leaks != null and _leaks.is_busy())


## Moves the effect clock on without a frame.
func advance_effects(seconds: float) -> void:
	_fx_time += seconds
	_finish_dying()
	_release_unclaimed()
	if _shots != null:
		_shots.advance(_fx_time)
	if _leaks != null:
		_leaks.advance(_fx_time)


# Clock.

func _advance_clock(alpha: float) -> void:
	var real_us: int = Time.get_ticks_usec()
	_real_dt = minf(float(real_us - _last_real_us) / 1000000.0, 0.1) if _last_real_us > 0 else 0.0
	_last_real_us = real_us
	var dt: float = _real_dt
	if battle.phase == Battle.Phase.WAVE:
		var game: float = (float(battle.tick) + clampf(alpha, 0.0, 1.0)) * float(Sim.MS_PER_TICK) / 1000.0
		dt = 0.0
		if _last_game >= 0.0 and game >= _last_game and game - _last_game <= 1.0:
			dt = game - _last_game
		_last_game = game
	else:
		_last_game = -1.0
	_fx_time += dt


# Towers.

func _sync_towers() -> void:
	for t: TowerState in battle.towers:
		var v: TowerView = _towers.get(t.cell)
		if v == null:
			v = _add_tower(t)
		elif v.tier != t.tier or v.spec != t.spec or v.type != t.type:
			_set_tower_look(v, t)
			v.born_t = _fx_time
		v.gen = _gen
		_animate_tower(v)
	if _towers.size() > battle.towers.size():
		var stale: Array[Vector2i] = []
		for cell: Vector2i in _towers:
			if _towers[cell].gen != _gen:
				stale.append(cell)
		for cell: Vector2i in stale:
			_release_sprite(_towers[cell].sprite)
			_towers.erase(cell)


func _add_tower(t: TowerState) -> TowerView:
	var v: TowerView = TowerView.new()
	v.cell = t.cell
	v.sprite = _acquire_sprite()
	v.sprite.z_index = 0
	v.sprite.position = _ground_px(t.cell)
	_set_tower_look(v, t)
	v.born_t = -10.0 if _first_sync else _fx_time
	_towers[t.cell] = v
	return v


func _set_tower_look(v: TowerView, t: TowerState) -> void:
	v.type = t.type
	v.tier = t.tier
	v.spec = t.spec
	var key: String = MapAtlas.tower_key(t.type, t.tier, t.spec)
	if not _atlas.has_key(key):
		_atlas.add_tower(t.type, t.tier, t.spec)
		_rebake()
	var e: MapAtlas.Entry = _atlas.entry_for(key)
	v.sprite.region_rect = e.rect
	v.sprite.offset = -e.anchor * _atlas.texel_scale


func _animate_tower(v: TowerView) -> void:
	var age: float = _fx_time - v.born_t
	var kick: float = _fx_time - v.kick_t
	if age >= 0.3 and kick >= 0.15:
		if not v.at_rest:
			v.at_rest = true
			v.sprite.scale = Vector2.ONE / _atlas.texel_scale
		return
	v.at_rest = false
	var sx: float = 1.0
	var sy: float = 1.0
	if age < 0.3:
		var k: float = clampf(age / 0.22, 0.0, 1.0)
		var back: float = 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
		sx = lerpf(0.6, 1.0, back)
		sy = sx
	if kick < 0.15:
		var s: float = sin(PI * kick / 0.15)
		sy *= 1.0 - 0.07 * s
		sx *= 1.0 + 0.04 * s
	v.sprite.scale = Vector2(sx, sy) / _atlas.texel_scale


# Creatures.

func _sync_creatures(alpha: float) -> void:
	_status_items.clear()
	var anim_rate: float = WALK_FPS
	for e: EnemyState in battle.enemies:
		var v: CreatureView = _creatures.get(e.id)
		if v == null:
			v = _add_creature(e)
		v.gen = _gen
		var p: Vector2 = Vector2(e.prev_pos).lerp(Vector2(e.pos), alpha)
		var c: Vector2 = p * PX_PER_SUB if v.flyer else _curve(p)
		if c.x < v.center.x - 0.05:
			v.left = true
		elif c.x > v.center.x + 0.05:
			v.left = false
		v.center = c
		v.sprite.position = Vector2(c.x, c.y + v.feet)
		v.sprite.flip_h = v.left
		anim_rate = FLAP_FPS if v.flyer else WALK_FPS
		var f: int = int(_fx_time * anim_rate + float(e.id) * 0.37) & 3
		if f != v.frame:
			v.frame = f
			v.sprite.region_rect = (_atlas.enemy_rects[v.type] as Array)[f]
		var it: MapStatus.Item = v.item
		it.center = c
		it.size = v.size_px
		it.hp = float(e.health) / float(maxi(e.max_health, 1))
		it.bar = e.health < e.max_health or v.boss
		it.drowsy = e.slow_ticks > 0 and e.slow_pct > 0
		it.bubble = e.bubble or v.bubble_hold > _fx_time
		it.frame = f
		if it.bar or it.drowsy or it.bubble:
			_status_items.append(it)
	if _creatures.size() > battle.enemies.size():
		var gone_ids: Array[int] = []
		for id: int in _creatures:
			if _creatures[id].gen != _gen:
				gone_ids.append(id)
		for id: int in gone_ids:
			_gone[id] = _creatures[id]
			_creatures.erase(id)


func _add_creature(e: EnemyState) -> CreatureView:
	var v: CreatureView = CreatureView.new()
	v.id = e.id
	v.type = e.type
	v.flyer = e.flying
	v.boss = Silhouettes.BOSSES.has(e.type)
	v.size_px = Silhouettes.enemy_size(e.type, CELL)
	v.feet = Silhouettes.FEET * v.size_px
	if not _atlas.enemy_rects.has(e.type):
		_atlas.add_enemy(e.type)
		_rebake()
	v.sprite = _acquire_sprite()
	v.sprite.z_index = Z_FLYER if v.flyer else 0
	v.sprite.flip_h = false
	var entry: MapAtlas.Entry = _atlas.entry_for(MapAtlas.enemy_key(e.type, 0))
	v.sprite.offset = -entry.anchor * _atlas.texel_scale
	v.sprite.scale = Vector2.ONE / _atlas.texel_scale
	v.center = Vector2(e.pos) * PX_PER_SUB
	_creatures[e.id] = v
	return v


## Creatures the sim removed that no event claimed (they got through): free them.
func _release_unclaimed() -> void:
	for id: int in _gone:
		_release_sprite(_gone[id].sprite)
	_gone.clear()


func _finish_dying() -> void:
	var i: int = 0
	while i < _dying.size():
		var v: CreatureView = _dying[i]
		if _fx_time >= v.pop_t:
			_pop(v)
			_dying.remove_at(i)
		else:
			i += 1


func _pop(v: CreatureView) -> void:
	var strength: float = 1.5 if v.boss else clampf(v.size_px / (CELL * 0.58), 0.6, 1.2)
	_sparkles.burst(v.center, MapSparkles.Kind.DEFEAT, strength)
	_release_sprite(v.sprite)


## Walkers follow the same round turns the roads are drawn with. `p` is in sub-units.
func _curve(p_sub: Vector2) -> Vector2:
	var p: Vector2 = p_sub * PX_PER_SUB
	var col: int = floori(p.x / CELL)
	var row: int = floori(p.y / CELL)
	if col < 0 or row < 0 or col >= Sim.MAP_COLUMNS or row >= level.rows:
		return p
	var t: int = _turn[row * Sim.MAP_COLUMNS + col]
	if t < 0:
		return p
	var a: Vector2 = Vector2(DIRS[t >> 2])
	var b: Vector2 = Vector2(DIRS[t & 3])
	var c: Vector2 = (Vector2(float(col), float(row)) + Vector2(0.5, 0.5)) * CELL
	var o: Vector2 = p - c
	var u: float = clampf(0.5 + (o.dot(b) - o.dot(a)) / CELL, 0.0, 1.0)
	var h: float = CELL * 0.5
	var corner: Vector2 = c + (a + b) * h
	var a0: float = (-b).angle()
	var delta: float = wrapf((-a).angle() - a0, -PI, PI)
	return corner + Vector2.from_angle(a0 + delta * u) * h


func _build_turns() -> void:
	_turn = PackedInt32Array()
	_turn.resize(Sim.MAP_COLUMNS * level.rows)
	_turn.fill(-1)
	for r: int in level.rows:
		for c: int in Sim.MAP_COLUMNS:
			var at: Vector2i = Vector2i(c, r)
			if not level.is_road(at):
				continue
			var dirs: Array[int] = []
			for i: int in 4:
				var n: Vector2i = at + DIRS[i]
				var outside: bool = n.x < 0 or n.y < 0 or n.x >= Sim.MAP_COLUMNS or n.y >= level.rows
				if level.is_road(n) or (outside and level.kind_at(at) == LevelData.Kind.ENTRANCE):
					dirs.append(i)
			if dirs.size() == 2 and DIRS[dirs[0]] + DIRS[dirs[1]] != Vector2i.ZERO:
				_turn[r * Sim.MAP_COLUMNS + c] = dirs[0] * 4 + dirs[1]


func _level_enemy_types() -> Array[StringName]:
	var out: Array[StringName] = []
	var todo: Array[StringName] = []
	for w: WaveData in level.waves:
		for g: WaveGroup in w.groups:
			todo.append(g.enemy)
	while not todo.is_empty():
		var id: StringName = todo.pop_back()
		if out.has(id):
			continue
		out.append(id)
		var t: EnemyType = battle.catalog.enemy(id)
		if t == null:
			continue
		if t.split_into != &"":
			todo.append(t.split_into)
		if not t.summon.is_empty():
			todo.append(StringName(t.summon["enemy"]))
		if not t.release.is_empty():
			todo.append(StringName(t.release["enemy"]))
	return out


# Events.

func _on_fired(e: Dictionary) -> void:
	var tower: StringName = e["tower"]
	var cell: Vector2i = e["cell"]
	var look: int = MapShots.look_for(tower, int(e["spec"]))
	var from: Vector2 = MapShots.muzzle(tower, cell)
	var v: TowerView = _towers.get(cell)
	if v != null:
		v.kick_t = _fx_time
	var ids: Array = e["targets"]
	var ats: Array = e["at"]
	for i: int in ids.size():
		var id: int = int(ids[i])
		var to: Vector2 = Vector2(ats[i] as Vector2i) * PX_PER_SUB
		var arrives: float = _shots.launch(look, from, to, id, _fx_time)
		_arrival_ids[id] = maxf(float(_arrival_ids.get(id, 0.0)), arrives)
		_arrival_pos.append(to)
		_arrival_time.append(arrives)


func _on_popped(id: int) -> void:
	var v: CreatureView = _find_view(id)
	if v == null:
		return
	var delay: float = _delay_for(id, v.center)
	v.bubble_hold = _fx_time + delay
	_shots.add_ring(v.center, _fx_time + delay)
	_sparkles.burst(v.center, MapSparkles.Kind.BUBBLE, 0.7)


## A creature got through: a dull puff at the home and a heart that floats up (the sprite
## itself is freed by _release_unclaimed, as the sim already removed it).
func _on_leaked(e: Dictionary) -> void:
	var home: Vector2 = _center_px(level.base)
	var lives: int = maxi(int(e["lives"]), 1)
	var boss: bool = Silhouettes.BOSSES.has(e["enemy"])
	_sparkles.burst(home, MapSparkles.Kind.LEAK, 1.4 if boss else (1.0 if lives > 1 else 0.8))
	_leaks.spawn(home, lives, boss, _fx_time)


func _on_defeated(id: int, pos_sub: Vector2) -> void:
	var v: CreatureView = _find_view(id)
	var at: Vector2 = pos_sub * PX_PER_SUB
	if v == null:
		_sparkles.burst(at, MapSparkles.Kind.DEFEAT, 1.0)
		return
	_gone.erase(id)
	_creatures.erase(id)
	v.center = at if v.flyer else _curve(pos_sub)
	v.sprite.position = Vector2(v.center.x, v.center.y + v.feet)
	v.item.bar = false
	var delay: float = _delay_for(id, v.center)
	v.pop_t = _fx_time + delay
	if delay <= 0.0:
		_pop(v)
	else:
		_dying.append(v)


func _find_view(id: int) -> CreatureView:
	var v: CreatureView = _creatures.get(id)
	if v == null:
		v = _gone.get(id)
	return v


## How long until the shot that hit this creature (or splashed it) arrives.
func _delay_for(id: int, at: Vector2) -> float:
	if _arrival_ids.has(id):
		return maxf(float(_arrival_ids[id]) - _fx_time, 0.0)
	var best: float = 0.0
	var best_d: float = CELL * 1.5
	for i: int in _arrival_pos.size():
		var d: float = _arrival_pos[i].distance_to(at)
		if d < best_d:
			best_d = d
			best = maxf(_arrival_time[i] - _fx_time, 0.0)
	return best


# Gates, layers and the sprite pool.

func _sync_gates() -> void:
	var cells: Array[Vector2i] = []
	var looks: Array[int] = []
	var build: bool = battle.phase == Battle.Phase.BUILD
	var movable: bool = battle.gates_in_hand > 0 or not battle.gates.is_empty()
	var refused: bool = _refused_cell.x >= 0 and Time.get_ticks_msec() < _refused_until
	for s: Vector2i in level.sockets:
		var look: int = -1
		for g: GateState in battle.gates:
			if g.cell == s:
				look = MapArt.Gate.FIXED if g.fixed else (MapArt.Gate.BROKEN if g.broken else MapArt.Gate.CLOSED)
		if look < 0 and build and movable:
			look = MapArt.Gate.SOCKET
		if refused and s == _refused_cell:
			look = MapArt.Gate.REFUSED
		if look >= 0:
			cells.append(s)
			looks.append(look)
	if not refused:
		_refused_cell = Vector2i(-1, -1)
	_gates.set_gates(cells, looks)


func _sync_layers() -> void:
	_shots.advance(_fx_time)
	_leaks.advance(_fx_time)
	if _shots.is_busy():
		_track_shots()
	_routes.advance(_real_dt)
	if _marks.is_animated():
		_marks.set_pulse(0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006))
	if _has_boost and _syncs % 6 == 1:
		_boosted.clear()
		for t: TowerState in battle.towers:
			var type: TowerType = battle.catalog.tower(t.type)
			if type != null and type.kind == &"attack":
				var n: Dictionary = battle.tower_numbers(t.cell)
				if int(n.get("got_pct", 0)) > 0 or int(n.get("got_damage", 0)) > 0:
					_boosted.append(_center_px(t.cell))
	_status.set_items(_status_items, _boosted)


## A shot follows its target while the target is still on the map.
func _track_shots() -> void:
	for s: MapShots.Shot in _shots.shots:
		var v: CreatureView = _creatures.get(s.target)
		if v != null:
			s.to = v.center


func _acquire_sprite() -> Sprite2D:
	var s: Sprite2D
	if _pool.is_empty():
		s = Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.region_filter_clip_enabled = true
		s.texture = _atlas.get_texture()
		s.material = _premult
		_entities.add_child(s)
	else:
		s = _pool.pop_back()
	s.visible = true
	return s


func _release_sprite(s: Sprite2D) -> void:
	s.visible = false
	_pool.append(s)


## Called when the node enters the tree and after fit(): redraws the sheets only when the
## sharpness they need changed.
func _refresh_bake() -> void:
	if _atlas == null or not is_inside_tree():
		return
	var screen: float = get_viewport().get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x
	var wanted: float = clampf(roundf(screen * 4.0) / 4.0, 1.0, 2.0)
	if absf(wanted - _bake_scale) < 0.01:
		return
	_bake_scale = wanted
	_ground.bake(_bake_scale)
	_rebake()


## Lays the sheet out again and refreshes every live sprite.
func _rebake() -> void:
	_atlas.bake(_bake_scale)
	_gates.refresh()
	var k: float = _atlas.texel_scale
	for cell: Vector2i in _towers:
		var v: TowerView = _towers[cell]
		var e: MapAtlas.Entry = _atlas.entry_for(MapAtlas.tower_key(v.type, v.tier, v.spec))
		v.sprite.region_rect = e.rect
		v.sprite.offset = -e.anchor * k
		v.sprite.scale = Vector2.ONE / k
		v.at_rest = true
	var all: Array[CreatureView] = []
	all.append_array(_creatures.values())
	all.append_array(_gone.values())
	all.append_array(_dying)
	for v: CreatureView in all:
		var e: MapAtlas.Entry = _atlas.entry_for(MapAtlas.enemy_key(v.type, 0))
		v.sprite.offset = -e.anchor * k
		v.sprite.scale = Vector2.ONE / k
		v.frame = -1


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_towers.clear()
	_creatures.clear()
	_gone.clear()
	_dying.clear()
	_pool.clear()
	_status_items.clear()
	_boosted.clear()
	_atlas = null
	_ground = null
	_entities = null
	_shots = null
	_status = null
	_sparkles = null
	_leaks = null


func _center_px(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func _ground_px(cell: Vector2i) -> Vector2:
	return _center_px(cell) + Vector2(0.0, Silhouettes.TOWER_GROUND * CELL)
