# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name GameData
extends RefCounted
## Every bundled data file, read through JsonFile and checked (docs/ARCHITECTURE.md 2.5, 2.12).
## A problem in a bundled file is a build bug: the App shows the damaged message.

const FORMAT: int = 1
const STATS_CAP: int = 262144
const LEVEL_CAP: int = 65536
const CAMPAIGN_CAP: int = 16384
const CAMPAIGN_FILE: String = "campaign.json"
## Most levels in one region. RULES 12 plans 6.
const REGION_LEVELS_MAX: int = 24

var problems: PackedStringArray = PackedStringArray()   # empty when every file is valid
var catalog: Catalog = null
var campaign: Array[Dictionary] = []                    # [{"id": StringName, "name": String, "levels": Array[StringName]}]
var levels: Dictionary[StringName, LevelData] = {}


static func load_from(root: String = "res://data") -> GameData:
	var game: GameData = GameData.new()
	game._load(root)
	return game


func _load(root: String) -> void:
	var stats_dir: String = root.path_join("stats")
	var towers: Variant = _read(stats_dir.path_join("towers.json"), "towers.json", STATS_CAP)
	var enemies: Variant = _read(stats_dir.path_join("enemies.json"), "enemies.json", STATS_CAP)
	var rules: Variant = _read(stats_dir.path_join("rules.json"), "rules.json", STATS_CAP)
	if not problems.is_empty():
		return
	var stat_problems: PackedStringArray = Catalog.check(towers, enemies, rules)
	if not stat_problems.is_empty():
		problems.append_array(stat_problems)
		return
	catalog = Catalog.from_data(towers, enemies, rules)
	var level_dir: String = root.path_join("levels")
	var order: Variant = _read(level_dir.path_join(CAMPAIGN_FILE), CAMPAIGN_FILE, CAMPAIGN_CAP)
	if not problems.is_empty():
		return
	var listed: Array[StringName] = _read_campaign(order)
	for id: StringName in listed:
		var file_name: String = String(id) + ".json"
		var before: int = problems.size()
		var data: Variant = _read(level_dir.path_join(file_name), file_name, LEVEL_CAP)
		if problems.size() > before:
			continue
		var level_problems: PackedStringArray = LevelData.check(data, catalog)
		if not level_problems.is_empty():
			problems.append_array(level_problems)
			continue
		var level: LevelData = LevelData.from_data(data, catalog)
		if level.id != id:
			problems.append("%s: id: must equal the file name" % file_name)
			continue
		levels[id] = level
	for file_name: String in DirAccess.get_files_at(level_dir):
		if file_name.get_extension() != "json" or file_name == CAMPAIGN_FILE:
			continue
		if not listed.has(StringName(file_name.get_basename())):
			problems.append("%s: is not listed in %s" % [file_name, CAMPAIGN_FILE])


## The parsed file, or null with a problem.
func _read(path: String, file_name: String, cap: int) -> Variant:
	var got: Dictionary = JsonFile.read(path, cap)
	var status: StringName = got["status"]
	if status == JsonFile.OK_STATUS:
		return got["data"]
	if status == JsonFile.MISSING:
		problems.append("%s: is missing" % file_name)
	elif status == JsonFile.LOCKED:
		problems.append("%s: cannot be opened" % file_name)
	else:
		problems.append("%s: is over %d bytes, not plain ASCII, or not valid JSON" % [file_name, cap])
	return null


## Checks campaign.json (2.5) and fills campaign. Returns every level id it lists, in order.
func _read_campaign(data: Variant) -> Array[StringName]:
	var listed: Array[StringName] = []
	var chk: DataCheck = DataCheck.new(CAMPAIGN_FILE)
	if chk.object(data, "", ["format", "regions"]):
		var top: Dictionary = data
		chk.integer(top, "format", "", FORMAT, FORMAT)
		var region_list: Array = chk.array(top, "regions", "", 1, catalog.rules.region_stars.size())
		var region_ids: Array[StringName] = []
		for r: int in region_list.size():
			var path: String = "regions[%d]" % r
			if not chk.object(region_list[r], path, ["id", "name", "levels"]):
				continue
			var item: Dictionary = region_list[r]
			var region_id: StringName = chk.ident(item, "id", path)
			if region_id != &"" and region_ids.has(region_id):
				chk.fail(path + ".id", "repeats %s" % region_id)
			region_ids.append(region_id)
			var region_name: String = chk.text(item, "name", path, 24)
			var ids: Array[StringName] = []
			var level_list: Array = chk.array(item, "levels", path, 1, REGION_LEVELS_MAX)
			for i: int in level_list.size():
				var level_path: String = "%s.levels[%d]" % [path, i]
				var id: StringName = chk.ident_value(level_list[i], level_path)
				if id == &"":
					continue
				if listed.has(id):
					chk.fail(level_path, "repeats %s" % id)
					continue
				listed.append(id)
				ids.append(id)
			campaign.append({"id": region_id, "name": region_name, "levels": ids})
	problems.append_array(chk.problems)
	return listed
