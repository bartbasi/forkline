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
	# Regions are added phase by phase, so only region 1 is pinned here.
	assert_true(game.campaign.size() >= 1)
	assert_eq(game.campaign[0]["id"], &"lantern_hill")
	assert_eq((game.campaign[0]["levels"] as Array).size(), 6)
	assert_eq(game.levels.size(), _listed(game), "every listed level loads, and no other")
	for region: Dictionary in game.campaign:
		var listed: Array[StringName] = region["levels"]
		for id: StringName in listed:
			assert_true(game.levels.has(id), String(id))
			assert_eq(game.levels[id].id, id)


## The level count over every region of the campaign.
func _listed(game: GameData) -> int:
	var count: int = 0
	for region: Dictionary in game.campaign:
		count += (region["levels"] as Array).size()
	return count


func test_copy_in_user_folder_loads_the_same() -> void:
	var game: GameData = GameData.load_from(root)
	assert_eq(game.problems, PackedStringArray())
	assert_eq(game.levels.size(), GameData.load_from().levels.size())
	assert_eq(game.levels.size(), _listed(game))


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


# phase 7: the run files (2.9 to 2.12)

const RunFx: GDScript = preload("res://tests/run/fixtures/run_fixtures.gd")


## The real run plan and cards, with the fixture segments and packs of tests/run/ until
## the real ones exist.
func _add_run_files() -> void:
	for relative: String in ["runs/run.json", "cards/cards.json"]:
		DirAccess.make_dir_recursive_absolute(root.path_join(relative.get_base_dir()))
		_put(relative, FileAccess.get_file_as_string(Fx.DATA.path_join(relative)))
	DirAccess.make_dir_recursive_absolute(root.path_join("segments"))
	var files: Dictionary = RunFx.files()
	for key: String in files:
		if key.begins_with("segments/"):
			_put(key, JSON.stringify(files[key]))


func test_the_run_files_load() -> void:
	_add_run_files()
	var game: GameData = GameData.load_from(root)
	assert_eq(game.problems, PackedStringArray())
	assert_not_null(game.run)
	if game.run == null:
		return
	assert_eq(game.run.card_ids().size(), 34, "the real cards")
	var order: Array[StringName] = []
	for id: String in RunFx.INDEX_ORDER:
		order.append(StringName(id))
	assert_eq(game.run.segment_ids, order, "the index order")
	assert_eq(game.run.packs.size(), 26)
	# A run builds from what was loaded.
	assert_not_null(RunSession.start(7, "", false, game.run.pool({}), game.run, game.catalog))


func test_no_segments_folder_means_no_run_yet() -> void:
	# Stopgap until data/segments/ lands (task L4): no folder, no run and no problem.
	var game: GameData = GameData.load_from(root)
	assert_eq(game.problems, PackedStringArray())
	assert_null(game.run)
	_add_run_files()
	assert_not_null(GameData.load_from(root).run, "with the folder, runs load")


func test_run_file_problems_are_reported_and_give_no_run() -> void:
	var cases: Dictionary = {
		"a listed segment missing": [func() -> void: DirAccess.remove_absolute(root.path_join("segments/mid_bend.json")), "mid_bend.json: is missing"],
		"packs not JSON": [func() -> void: _put("segments/packs.json", "{\"format\": 1, \"packs\": ["), "packs.json: is over"],
		"run plan missing": [func() -> void: DirAccess.remove_absolute(root.path_join("runs/run.json")), "run.json: is missing"],
		"cards missing": [func() -> void: DirAccess.remove_absolute(root.path_join("cards/cards.json")), "cards.json: is missing"],
		"index missing": [func() -> void: DirAccess.remove_absolute(root.path_join("segments/index.json")), "index.json: is missing"],
		"run plan over its cap": [func() -> void: _put("runs/run.json", "{\"pad\": \"" + "a".repeat(GameData.RUN_CAP) + "\"}"), "run.json: is over"],
		"segment over its cap": [func() -> void: _put("segments/top_one.json", "{\"pad\": \"" + "a".repeat(GameData.SEGMENT_CAP) + "\"}"), "top_one.json: is over"],
		"segment of high bytes": [func() -> void: _put("segments/bot_home.json", "{\"id\": \"café\"}"), "bot_home.json"],
		"segment id not its file name": [func() -> void: _edit_json("segments/bot_edge.json", func(d: Dictionary) -> void: d["id"] = "bot_home"), "bot_edge"],
		"index naming a path": [func() -> void: _edit_json("segments/index.json", func(d: Dictionary) -> void: (d["segments"] as Array).append("../stats/rules")), "index.json"],
		"cards broken": [func() -> void: _edit_json("cards/cards.json", func(d: Dictionary) -> void: d["cards"][0]["once"] = "yes"), "cards.json"],
	}
	for name: String in cases:
		before_each()
		_add_run_files()
		var item: Array = cases[name]
		(item[0] as Callable).call()
		var game: GameData = GameData.load_from(root)
		assert_true(_has_problem(game, item[1]), "%s: %s" % [name, str(game.problems)])
		assert_null(game.run, name)
		assert_not_null(game.catalog, "%s: the rest still loads" % name)


func test_only_listed_segments_are_read() -> void:
	_add_run_files()
	# A file the index does not list is never read, so even a broken one changes nothing.
	# tests/levels/ checks that every file in the folder is listed (2.9).
	_put("segments/stray.json", "{\"format\": 1, \"id\": ")
	var game: GameData = GameData.load_from(root)
	assert_eq(game.problems, PackedStringArray())
	assert_not_null(game.run)
	assert_false(game.run.segment_ids.has(&"stray"))
	# An index over 256 entries is a problem, and none of its files are read.
	_edit_json("segments/index.json", _grow_index)
	game = GameData.load_from(root)
	assert_null(game.run)
	assert_true(_has_problem(game, "index.json"), str(game.problems))


func _grow_index(d: Dictionary) -> void:
	for i: int in 300:
		(d["segments"] as Array).append("seg_%d" % i)
