# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## An App wired to a throwaway save folder, for the flow tests. Load it with preload;
## it has no class name. The AudioService takes about a second to build and free, so
## one is shared by every test that needs a service.

const BattleFixtures: GDScript = preload("res://tests/ui/battle_fixtures.gd")
const COVER: Vector2 = Vector2(1080.0, 2767.0)
const COVER_SAFE: Rect2 = Rect2(0.0, 96.0, 1080.0, 2500.0)
const INNER: Vector2 = Vector2(1998.0, 2400.0)
const INNER_SAFE: Rect2 = Rect2(0.0, 0.0, 1998.0, 2250.0)

static var _audio: AudioService = null


static func audio() -> AudioService:
	if _audio == null:
		_audio = AudioService.new()
		_audio.set_enabled(true)
	return _audio


static func dir(tag: String) -> String:
	return "user://tests/ui/%s/" % tag


## Removes every file a test left in its folder.
static func wipe(tag: String) -> void:
	var path: String = dir(tag)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + file_name)


## A built, laid out App on the cover screen. The saves go to a folder of their own.
static func app(tag: String, fresh: bool = true) -> App:
	if fresh:
		wipe(tag)
	var made: App = App.new()
	made.game = BattleFixtures.game()
	made.store = SaveStore.new(dir(tag))
	made.audio = audio()
	made.end_delay = 0.0
	made.build()
	made.apply_layout(COVER, COVER_SAFE)
	return made


## Every tower and creature already met, so no first sight card opens.
static func mark_all_seen(made: App) -> void:
	for id: StringName in made.game.catalog.tower_ids():
		made.progress.mark_seen(id)
	for id: StringName in made.game.catalog.enemy_ids():
		made.progress.mark_seen(id)
	for id: StringName in made.game.levels:
		made.progress.mark_seen(id)


## Builds a tower the way a player does: tap the spot, pick the tower, confirm.
static func build(screen: BattleScreen, cell: Vector2i, type: StringName) -> bool:
	screen.tap_at(cell)
	if screen.context_panel() != screen.build_panel:
		return false
	screen.build_panel.select_tower(type)
	screen.build_panel.confirm()
	return screen.battle.tower_at(cell) != null


## Runs frames of 0.05 s at 3x until `done` is true or `limit` frames pass.
static func run(screen: BattleScreen, limit: int, done: Callable) -> void:
	screen.clock.speed = 3
	for i: int in limit:
		if done.call():
			return
		screen.frame(0.05)


## Plays a level to its end through the screen's own panels: build and upgrade with
## all the gold, start each wave from the HUD button, step frames. Returns true on a win.
static func play_out(screen: BattleScreen, limit: int = 30000) -> bool:
	var b: Battle = screen.battle
	var frames: int = 0
	while b.phase != Battle.Phase.WON and b.phase != Battle.Phase.LOST and frames < limit:
		if b.phase == Battle.Phase.BUILD:
			_spend(screen)
			screen.hud.call_button.tapped.emit()
		screen.frame(0.05)
		frames += 1
	screen.frame(0.05)
	return b.phase == Battle.Phase.WON


static func _spend(screen: BattleScreen) -> void:
	var b: Battle = screen.battle
	var types: Array[StringName] = b.level.towers
	var n: int = 0
	for cell: Vector2i in b.level.spots:
		if b.tower_at(cell) == null:
			if build(screen, cell, types[n % types.size()]):
				n += 1
		else:
			screen.tap_at(cell)
			if screen.tower_panel.is_open():
				var tower: TowerState = b.tower_at(cell)
				if tower.tier == 1:
					screen.tower_panel.upgrade()
				elif tower.tier == 2:
					screen.tower_panel.pick_path(0)
					screen.tower_panel.confirm_path()
	screen.close_context()
