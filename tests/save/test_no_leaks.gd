# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Save objects are freed as soon as their last user lets go (QA p7).

const Fx: GDScript = preload("res://tests/save/fixtures/save_fixtures.gd")


func before_each() -> void:
	Fx.fresh()


func after_each() -> void:
	Fx.clean()


func test_store_game_data_and_loaded_saves_are_freed() -> void:
	var game: GameData = Fx.game()
	var store: SaveStore = SaveStore.new(Fx.WORK)
	assert_true(store.save_game(Fx.saved(SavedGame.LEVEL, Fx.battle_mid_wave(game, &"r1_l1", false, 120))), "the game saves")
	assert_true(store.save_settings(Settings.from_data({"format": 1, "sound": false})), "settings save")
	assert_true(store.save_progress(Progress.from_data({})), "progress saves")
	var loaded: Array[SavedGame] = store.load_games(game)
	assert_eq(loaded.size(), 1, "the saved game loads")
	var settings: Settings = store.load_settings()
	var progress: Progress = store.load_progress()
	assert_false(settings.sound_on, "the saved setting reads back")
	var refs: Dictionary[String, WeakRef] = {
		"game data": weakref(game),
		"catalog": weakref(game.catalog),
		"store": weakref(store),
		"settings": weakref(settings),
		"progress": weakref(progress),
		"saved game": weakref(loaded[0]),
		"saved battle": weakref(loaded[0].battle),
	}
	game = null
	store = null
	settings = null
	progress = null
	loaded.clear()
	for key: String in refs:
		assert_null(refs[key].get_ref(), key + " is freed")
