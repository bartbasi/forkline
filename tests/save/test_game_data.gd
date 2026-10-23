# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## GameData: every bundled file through JsonFile, Catalog and LevelData, and the
## campaign list (docs/ARCHITECTURE.md 2.5, 2.12).

const Fx: GDScript = preload("res://tests/save/fixtures/save_fixtures.gd")

var root: String = Fx.path("data")


func before_each() -> void:
	Fx.fresh()
	for sub: String in ["stats", "levels"]:
		DirAccess.make_dir_recursive_absolute(root.path_join(sub))
		for file_name: String in DirAccess.get_files_at(Fx.DATA.path_join(sub)):
			if file_name.get_extension() == "json":
				_put(sub + "/" + file_name, FileAccess.get_file_as_string(Fx.DATA.path_join(sub).path_join(file_name)))


func after_each() -> void:
	Fx.clean()


func _put(relative: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(root.path_join(relative), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _edit_json(relative: String, change: Callable) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(relative)))
	change.call(data)
	_put(relative, JSON.stringify(data))


func _has_problem(game: GameData, part: String) -> bool:
	for problem: String in game.problems:
		if problem.contains(part):
			return true
	return false


func test_real_data_loads_with_no_problems() -> void:
	var game: GameData = GameData.load_from()
	assert_eq(game.problems, PackedStringArray())
	assert_not_null(game.catalog)
	assert_eq(game.campaign.size(), 1)
	assert_eq(game.campaign[0]["id"], &"lantern_hill")
	var listed: Array[StringName] = game.campaign[0]["levels"]
	assert_eq(listed.size(), 6)
	for id: StringName in listed:
		assert_true(game.levels.has(id), String(id))
		assert_eq(game.levels[id].id, id)


func test_copy_in_user_folder_loads_the_same() -> void:
	var game: GameData = GameData.load_from(root)
	assert_eq(game.problems, PackedStringArray())
	assert_eq(game.levels.size(), 6)


func test_level_id_must_equal_its_file_name() -> void:
	_edit_json("levels/r1_l2.json", func(d: Dictionary) -> void: d["id"] = "r1_l3")
	var game: GameData = GameData.load_from(root)
	assert_true(_has_problem(game, "r1_l2.json: id: must equal the file name"), str(game.problems))
	assert_false(game.levels.has(&"r1_l2"))


func test_unlisted_and_missing_levels_are_problems() -> void:
	_put("levels/r9_l9.json", FileAccess.get_file_as_string(root.path_join("levels/r1_l1.json")))
	DirAccess.remove_absolute(root.path_join("levels/r1_l4.json"))
	var game: GameData = GameData.load_from(root)
	assert_true(_has_problem(game, "r9_l9.json: is not listed"), str(game.problems))
	assert_true(_has_problem(game, "r1_l4.json: is missing"), str(game.problems))


func test_campaign_shape_is_checked() -> void:
	var bad: Array = [
		"[]",
		"{\"format\": 1}",
		"{\"format\": 2, \"regions\": []}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": [\"r1_l1\", \"r1_l1\"]}]}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": [\"../stats/rules\"]}]}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": [\"r1_l1\"], \"extra\": 1}]}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"\", \"levels\": [\"r1_l1\"]}]}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": [\"r1_l1\"]}, {\"id\": \"a\", \"name\": \"B\", \"levels\": [\"r1_l2\"]}]}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": 7}]}",
		"{\"format\": 1e999, \"regions\": []}",
		"{\"format\": 1, \"regions\": [{\"id\": \"a\", \"name\": \"A\", \"levels\": [\"r1_l1\"]}, {\"id\": \"b\", \"name\": \"B\", \"levels\": [\"r1_l2\"]}, {\"id\": \"c\", \"name\": \"C\", \"levels\": [\"r1_l3\"]}, {\"id\": \"d\", \"name\": \"D\", \"levels\": [\"r1_l4\"]}, {\"id\": \"e\", \"name\": \"E\", \"levels\": [\"r1_l5\"]}]}",
		"{\"format\": 1, \"regions\": [" + "[".repeat(3000) + "]".repeat(3000) + "]}",
	]
	for text: String in bad:
		_put("levels/campaign.json", text)
		var game: GameData = GameData.load_from(root)
		assert_false(game.problems.is_empty(), text.left(80))


func test_bad_stats_and_hostile_files_are_problems() -> void:
	_edit_json("stats/rules.json", func(d: Dictionary) -> void: d["start_lives"] = -5)
	var game: GameData = GameData.load_from(root)
	assert_true(_has_problem(game, "rules.json"), str(game.problems))
	assert_null(game.catalog)
	before_each()
	_put("stats/towers.json", "{\"format\": 1, \"towers\": [")
	game = GameData.load_from(root)
	assert_true(_has_problem(game, "towers.json"), str(game.problems))
	before_each()
	var high: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join("levels/r1_l1.json"))
	high[20] = 0xC3
	var file: FileAccess = FileAccess.open(root.path_join("levels/r1_l1.json"), FileAccess.WRITE)
	file.store_buffer(high)
	file.close()
	game = GameData.load_from(root)
	assert_true(_has_problem(game, "r1_l1.json"), str(game.problems))
	before_each()
	_put("levels/r1_l3.json", "{\"pad\": \"" + "a".repeat(GameData.LEVEL_CAP) + "\"}")
	game = GameData.load_from(root)
	assert_true(_has_problem(game, "r1_l3.json: is over"), str(game.problems))
	before_each()
	DirAccess.remove_absolute(root.path_join("stats/enemies.json"))
	game = GameData.load_from(root)
	assert_true(_has_problem(game, "enemies.json: is missing"), str(game.problems))


func test_missing_root_is_a_problem_not_a_crash() -> void:
	var game: GameData = GameData.load_from(Fx.path("nowhere"))
	assert_false(game.problems.is_empty())
	assert_null(game.catalog)
	assert_eq(game.levels.size(), 0)
