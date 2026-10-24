# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Shared helpers for tests/save/. Every test writes only inside WORK, a folder under
## user://tests/save/ that each test removes in before_each() and after_each(). WORK is
## named after the process, so two test runs at once never wipe each other's files.

const TEST_ROOT: String = "user://tests/save"
const DATA: String = "res://data"
static var WORK: String = "%s/work_%d" % [TEST_ROOT, OS.get_process_id()]


## Removes WORK and everything in it, then makes it again, empty.
static func fresh() -> void:
	clean()
	DirAccess.make_dir_recursive_absolute(WORK)


## Removes this run's WORK, then the parent folders if no other run still uses them.
## Refuses any path outside user://tests/save.
static func clean() -> void:
	_remove_tree(WORK)
	DirAccess.remove_absolute(TEST_ROOT)               # only succeeds when empty
	DirAccess.remove_absolute("user://tests")


static func _remove_tree(dir_path: String) -> void:
	if not dir_path.begins_with(TEST_ROOT + "/") or dir_path.contains(".."):
		return
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)


static func path(file_name: String) -> String:
	return WORK.path_join(file_name)


static func write_bytes(file_name: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path(file_name), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


static func write_text(file_name: String, text: String) -> void:
	write_bytes(file_name, text.to_utf8_buffer())


static func read_text(file_name: String) -> String:
	if not FileAccess.file_exists(path(file_name)):
		return ""
	return FileAccess.get_file_as_string(path(file_name))


static func exists(file_name: String) -> bool:
	return FileAccess.file_exists(path(file_name))


static func game() -> GameData:
	return GameData.load_from(DATA)


## A campaign level battle, played into its first wave so creatures are on the map.
static func battle_mid_wave(game_data: GameData, level_id: StringName, relaxed: bool, ticks: int) -> Battle:
	var battle: Battle = Battle.create(game_data.levels[level_id], game_data.catalog, relaxed, [])
	var spot: Vector2i = battle.level.spots[0]
	battle.place_tower(spot, battle.level.towers[0])
	battle.start_next_wave()
	for i: int in ticks:
		battle.step()
	return battle


static func saved(mode: StringName, battle: Battle) -> SavedGame:
	var game_save: SavedGame = SavedGame.new()
	game_save.mode = mode
	game_save.level_id = battle.level.id if mode == SavedGame.LEVEL else &""
	game_save.battle = battle
	return game_save


static func battle_text(battle: Battle) -> String:
	return JSON.stringify(battle.to_data())


## Every hostile byte pattern a file can hold, by name. Each must fall back safely.
static func hostile_files(valid_text: String, cap: int) -> Dictionary:
	var cases: Dictionary = {}
	cases["empty"] = PackedByteArray()
	cases["truncated"] = valid_text.left(valid_text.length() / 2).to_ascii_buffer()
	cases["corrupt"] = "{\"format\": 1, \"sound\": tru".to_ascii_buffer()
	cases["garbage"] = PackedByteArray([0xff, 0xfe, 0x00, 0x41, 0x7b, 0x22, 0x10, 0x80])
	var nul_end: PackedByteArray = "{\"format\": 1}".to_ascii_buffer()
	nul_end.append(0)
	cases["nul byte"] = nul_end
	var nul_inside: PackedByteArray = valid_text.to_ascii_buffer()
	nul_inside[nul_inside.size() / 2] = 0
	cases["nul inside"] = nul_inside
	cases["high bytes"] = "{\"format\": 1, \"x\": \"café\"}".to_utf8_buffer()
	cases["huge"] = ("{\"format\": 1, \"pad\": \"" + "a".repeat(cap) + "\"}").to_ascii_buffer()
	cases["deep nesting"] = ("{\"format\": 1, \"levels\": " + "[".repeat(5000) + "]".repeat(5000) + "}").to_ascii_buffer()
	cases["deep objects"] = ("{\"format\": 1, \"sound\": " + "{\"a\":".repeat(3000) + "1" + "}".repeat(3000) + "}").to_ascii_buffer()
	cases["array root"] = "[1, 2, 3]".to_ascii_buffer()
	cases["string root"] = "\"settings\"".to_ascii_buffer()
	cases["number root"] = "1e999".to_ascii_buffer()
	cases["null root"] = "null".to_ascii_buffer()
	cases["nan"] = "{\"format\": NaN}".to_ascii_buffer()
	cases["infinity"] = "{\"format\": 1e999}".to_ascii_buffer()
	cases["negative infinity"] = "{\"format\": -1e999}".to_ascii_buffer()
	cases["format as text"] = "{\"format\": \"1\"}".to_ascii_buffer()
	cases["format fraction"] = "{\"format\": 1.5}".to_ascii_buffer()
	cases["format zero"] = "{\"format\": 0}".to_ascii_buffer()
	cases["object text"] = "{\"format\": \"Object(Node,\\\"script\\\":\\\"res://x.gd\\\")\"}".to_ascii_buffer()
	cases["resource path"] = "{\"format\": 1, \"battle\": \"res://src/sim/battle.gd\", \"sound\": \"res://x.tres\"}".to_ascii_buffer()
	cases["only spaces"] = "    \n\t  ".to_ascii_buffer()
	return cases
