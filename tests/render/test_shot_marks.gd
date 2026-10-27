# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## The three parts of every tower shot (docs/ARCHITECTURE.md 9.3): a mark where it leaves, a body in
## flight, and a mark where it lands. The catapult shows its true splash area, read from the tower's
## stats. Played on a real Battle on the arena map of render_fixtures.gd.

const Fx: GDScript = preload("res://tests/render/render_fixtures.gd")
const GUARD_TICKS: int = 2000

var _views: Array[MapView] = []


func after_each() -> void:
	for v: MapView in _views:
		if is_instance_valid(v):
			if v.get_parent() != null:
				v.get_parent().remove_child(v)
			v.free()
	_views.clear()


func _view(b: Battle) -> MapView:
	var v: MapView = MapView.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(v)
	v.setup(b)
	_views.append(v)
	return v


## Plays ticks until the tower has fired once. Returns false if it never did.
func _until_fired(b: Battle, v: MapView) -> bool:
	var shots: MapShots = v.get("_shots") as MapShots
	var ticks: int = 0
	while b.phase == Battle.Phase.WAVE and ticks < GUARD_TICKS:
		var events: Array[Dictionary] = Fx.tick(b)
		v.sync(1.0)
		v.play_events(events)
		ticks += 1
		if not shots.shots.is_empty():
			return true
	return false


func test_a_catapult_shows_the_towers_real_splash_area() -> void:
	# [tier, spec, splash in hundredths of a tile].
	var cases: Array = [[1, -1, 75], [2, -1, 125], [3, 0, 150], [3, 1, 125]]
	for c: Array in cases:
		var label: String = "tier %d spec %d" % [c[0], c[1]]
		var b: Battle = Fx.arena([[Fx.group("scamp", 6, 200)]], 1000)
		assert_true(Fx.build(b, Vector2i(4, 2), &"pumpkin_catapult", c[0], c[1]), label)
		assert_eq(b.towers[0].stats.splash, c[2], "%s: the stats" % label)
		var v: MapView = _view(b)
		var shots: MapShots = v.get("_shots") as MapShots
		b.start_next_wave()
		assert_true(_until_fired(b, v), "%s: it fired" % label)
		var want: float = float(c[2]) / 100.0 * MapView.CELL
		var shot: MapShots.Shot = shots.shots[0]
		assert_true(MapShots.is_lobbed(shot.look), label)
		assert_near(shot.radius, want, 0.01, "%s: the ground mark has the splash radius" % label)
		var hits: int = shots.marked[MapShots.Fx.HIT]
		v.advance_effects(0.3)
		assert_true(shots.marked[MapShots.Fx.SPLASH] >= 1, "%s: a splash where it landed" % label)
		assert_eq(shots.marked[MapShots.Fx.HIT], hits, "%s: no plain hit mark" % label)
		var radius: float = 0.0
		for f: MapShots.Flash in shots.flashes:
			if f.kind == MapShots.Fx.SPLASH:
				radius = f.size
		assert_near(radius, want, 0.01, "%s: the splash reaches its true radius" % label)


func test_every_shot_has_a_mark_where_it_leaves_and_where_it_lands() -> void:
	for look: int in MapShots.Look.values():
		var shots: MapShots = MapShots.new()
		var from: Vector2 = Vector2(2.0, 2.0) * MapShots.CELL
		var arrives: float = shots.launch(look, from, from + Vector2(3.0, 1.0) * MapShots.CELL, 1, 0.0, 96.0)
		assert_eq(shots.marked[MapShots.Fx.MUZZLE], 1, "look %d: a mark at the tower" % look)
		assert_true(arrives <= 0.25, "look %d: flies for %.2f s" % [look, arrives])
		shots.advance(arrives + 0.01)
		assert_eq(shots.shots.size(), 0, "look %d: it landed" % look)
		var landed: int = shots.marked[MapShots.Fx.HIT] + shots.marked[MapShots.Fx.SPLASH]
		assert_eq(landed, 1, "look %d: one mark where it landed" % look)
		if MapShots.is_lobbed(look):
			assert_eq(shots.marked[MapShots.Fx.SPLASH], 1, "look %d: a splash" % look)
		shots.advance(arrives + 2.0)
		assert_false(shots.is_busy(), "look %d: every mark ends" % look)
		shots.free()


func test_a_lobbed_shot_lands_where_the_hit_was_worked_out() -> void:
	var b: Battle = Fx.arena([[Fx.group("scamp", 6, 200)]], 1000)
	assert_true(Fx.build(b, Vector2i(4, 2), &"pumpkin_catapult", 1))
	var v: MapView = _view(b)
	var shots: MapShots = v.get("_shots") as MapShots
	b.start_next_wave()
	assert_true(_until_fired(b, v))
	var shot: MapShots.Shot = shots.shots[0]
	var spot: Vector2 = shot.to
	for i: int in 3:
		v.sync(1.0)
		Fx.tick(b)
	assert_eq(shot.to, spot, "it does not follow the creature, which walks on")


func test_a_tower_kicks_back_when_it_fires_and_settles() -> void:
	var b: Battle = Fx.arena([[Fx.group("scamp", 2, 400)]], 1000)
	assert_true(Fx.build(b, Vector2i(4, 2), &"pumpkin_catapult", 1))
	var v: MapView = _view(b)
	b.start_next_wave()
	assert_true(_until_fired(b, v))
	for i: int in 2:
		v.sync(1.0)
		Fx.tick(b)
	v.sync(1.0)
	var tower: MapView.TowerView = (v.get("_towers") as Dictionary)[Vector2i(4, 2)]
	assert_true(absf(tower.kick_lean) > 0.05, "it leans")
	assert_true(tower.kick_lean > 0.0, "away from a target on its left")
	assert_true(absf(tower.sprite.rotation) > 0.01, "and shows it")
	var ticks: int = 0
	while b.phase == Battle.Phase.WAVE and ticks < GUARD_TICKS:
		Fx.tick(b)
		ticks += 1
	v.advance_effects(2.0)
	v.sync(0.0)
	assert_near(tower.sprite.rotation, 0.0, 0.0001, "back upright")


func test_shots_and_marks_stay_inside_their_caps() -> void:
	var shots: MapShots = MapShots.new()
	for i: int in 400:
		shots.launch(i % MapShots.Look.size(), Vector2.ZERO, Vector2(200.0, 100.0), i, 0.0, 96.0)
	assert_true(shots.shots.size() <= MapShots.MAX_SHOTS, "%d shots" % shots.shots.size())
	assert_true(shots.flashes.size() <= MapShots.MAX_FLASHES, "%d marks" % shots.flashes.size())
	shots.advance(1.0)
	assert_true(shots.flashes.size() <= MapShots.MAX_FLASHES, "%d marks after landing" % shots.flashes.size())
	shots.free()


func test_every_shot_piece_is_on_the_sheet() -> void:
	assert_eq(ShotPieces.TILES.size(), ShotPieces.Piece.size(), "a tile size for every piece")
	assert_eq(ShotPieces.ANCHORS.size(), ShotPieces.Piece.size(), "an anchor for every piece")
	var atlas: MapAtlas = MapAtlas.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(atlas)
	atlas.add_shot_pieces()
	atlas.add_shot_pieces()
	atlas.bake(1.0)
	assert_eq(atlas.entries.size(), ShotPieces.Piece.size(), "added once")
	for piece: int in ShotPieces.Piece.size():
		var e: MapAtlas.Entry = atlas.entry_for(ShotPieces.key(piece))
		assert_not_null(e, "piece %d" % piece)
		if e != null:
			assert_true(e.rect.size.x > 0.0 and e.rect.size.y > 0.0, "piece %d has room on the sheet" % piece)
			assert_true(e.anchor.x <= e.tile.x and e.anchor.y <= e.tile.y, "piece %d anchor is inside its tile" % piece)
	tree.root.remove_child(atlas)
	atlas.free()
