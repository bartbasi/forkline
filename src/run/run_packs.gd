# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RunPacks
extends RefCounted
## Checks data/segments/packs.json (docs/ARCHITECTURE.md 2.9). Internal to src/run/:
## RunData calls it. A pack is read into a plain Dictionary:
## {"id": StringName, "band": int, "boss": StringName, "waves": Array of {"groups": Array of
## {"enemy": String, "count": int, "entrance": int, "at_ms": int, "every_ms": int}}}.
## Group fields stay in the file's units (1 based entrance, milliseconds).

## Equal to RunData.BANDS (a test checks). RunPacks does not name RunData, so the two
## scripts never refer to each other.
const BANDS: int = 6
const PACKS_MAX: int = 256
const WAVES: int = 3
const MIN_PER_BAND: int = 4
const SCAMP: StringName = &"scamp"
const GROUP_KEYS: PackedStringArray = ["enemy", "count", "entrance", "at_ms", "every_ms"]


## bands: run.json's six creature lists as arrays of StringName, or [] when run.json is
## unusable (the creature rules are then skipped). risks: [{"id": StringName, "effects":
## Array[Dictionary]}] for each risk card, for the spawn bound.
static func read(data: Variant, catalog: Catalog, bands: Array, risks: Array, problems: PackedStringArray) -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	var chk: DataCheck = DataCheck.new("packs.json")
	if chk.object(data, "", ["format", "packs"]):
		var top: Dictionary = data
		chk.integer(top, "format", "", 1, 1)
		var list: Array = chk.array(top, "packs", "", 1, PACKS_MAX)
		var seen: Array[StringName] = []
		for i: int in list.size():
			var pack: Dictionary = _read_pack(list[i], "packs[%d]" % i, catalog, bands, risks, chk)
			if pack.is_empty():
				continue
			if seen.has(pack["id"]):
				chk.fail("packs[%d].id" % i, "repeats %s" % pack["id"])
				continue
			seen.append(pack["id"])
			packs.append(pack)
		_check_totals(packs, catalog, chk)
	problems.append_array(chk.problems)
	return packs


static func _read_pack(raw: Variant, path: String, catalog: Catalog, bands: Array, risks: Array, chk: DataCheck) -> Dictionary:
	if not chk.object(raw, path, ["id", "band", "boss", "waves"]):
		return {}
	var item: Dictionary = raw
	var id: StringName = chk.ident(item, "id", path)
	var band: int = chk.integer(item, "band", path, 1, BANDS, 1, 0)
	var boss: StringName = &""
	if item.has("boss"):
		var boss_value: Variant = item["boss"]
		if not DataCheck.is_string(boss_value):
			chk.fail(DataCheck.join(path, "boss"), "must be a boss id, or empty")
		elif String(boss_value) != "":
			boss = chk.ident(item, "boss", path)
			var type: EnemyType = catalog.enemy(boss)
			if boss != &"" and (type == null or not type.boss):
				chk.fail(DataCheck.join(path, "boss"), "names no boss")
				boss = &""
	if band >= 1 and band < BANDS and boss != &"":
		chk.fail(DataCheck.join(path, "boss"), "must be empty in bands 1 to %d" % (BANDS - 1))
	if band == BANDS and boss == &"":
		chk.fail(DataCheck.join(path, "boss"), "a band %d pack names its boss" % BANDS)
	var waves: Array[Dictionary] = []
	var wave_list: Array = chk.array(item, "waves", path, WAVES, WAVES)
	for w: int in wave_list.size():
		waves.append(_read_wave(wave_list[w], "%s.waves[%d]" % [path, w], catalog, chk))
	if id == &"" or band == 0:
		return {}
	var pack: Dictionary = {"id": id, "band": band, "boss": boss, "waves": waves}
	if waves.size() == WAVES:
		_check_creatures(pack, path, catalog, bands, chk)
		_check_spawn_bound(pack, path, catalog, risks, chk)
	return pack


static func _read_wave(raw: Variant, path: String, catalog: Catalog, chk: DataCheck) -> Dictionary:
	var groups: Array[Dictionary] = []
	if not chk.object(raw, path, ["groups"]):
		return {"groups": groups}
	var wave: Dictionary = raw
	var list: Array = chk.array(wave, "groups", path, 1, LevelData.MAX_GROUPS)
	for g: int in list.size():
		var group_path: String = "%s.groups[%d]" % [path, g]
		if not chk.object(list[g], group_path, GROUP_KEYS):
			continue
		var item: Dictionary = list[g]
		var enemy: StringName = chk.ident(item, "enemy", group_path)
		if enemy != &"" and not catalog.has_enemy(enemy):
			chk.fail(DataCheck.join(group_path, "enemy"), "names no creature")
		groups.append({
			"enemy": String(enemy),
			"count": chk.integer(item, "count", group_path, 1, 200, 1, 1),
			"entrance": chk.integer(item, "entrance", group_path, 1, 2, 1, 1),
			"at_ms": chk.integer(item, "at_ms", group_path, 0, 600000, 50),
			"every_ms": chk.integer(item, "every_ms", group_path, 50, 60000, 50, 50),
		})
	return {"groups": groups}


## Which creatures a pack may use (2.9), the first wave of band 1, and the boss group.
static func _check_creatures(pack: Dictionary, path: String, catalog: Catalog, bands: Array, chk: DataCheck) -> void:
	var band: int = pack["band"]
	var boss: StringName = pack["boss"]
	var allowed: Array[String] = []
	if bands.size() == BANDS:
		for b: int in band:
			for creature: Variant in bands[b]:
				allowed.append(String(creature))
	var boss_groups: int = 0
	var waves: Array = pack["waves"]
	for w: int in waves.size():
		var groups: Array = (waves[w] as Dictionary)["groups"]
		for g: int in groups.size():
			var group: Dictionary = groups[g]
			var enemy: StringName = StringName(String(group["enemy"]))
			var type: EnemyType = catalog.enemy(enemy)
			if type == null:
				continue
			var group_path: String = "%s.waves[%d].groups[%d].enemy" % [path, w, g]
			if type.boss:
				if enemy != boss:
					chk.fail(group_path, "a boss comes only in the band %d pack that names it" % BANDS)
					continue
				boss_groups += 1
				if w != WAVES - 1 or int(group["count"]) != 1:
					chk.fail(group_path, "the boss comes in the third wave, as one group of 1")
			elif not allowed.is_empty() and not allowed.has(String(enemy)):
				chk.fail(group_path, "is not added by bands 1 to %d" % band)
			if band == 1 and w == 0 and enemy != SCAMP:
				chk.fail(group_path, "the first wave of a band 1 pack holds only %s" % SCAMP)
	if boss != &"" and boss_groups != 1:
		chk.fail(DataCheck.join(path, "waves"), "must hold the boss in exactly one group")


## One wave spawns at most 120 creatures, with no risk card and with each risk card of
## cards.json in turn. A band 6 pack's third wave (the boss wave) never gets a risk card.
static func _check_spawn_bound(pack: Dictionary, path: String, catalog: Catalog, risks: Array, chk: DataCheck) -> void:
	var waves: Array = pack["waves"]
	var none: Array[Dictionary] = []
	for w: int in waves.size():
		var groups: Array = (waves[w] as Dictionary)["groups"]
		var wave_path: String = "%s.waves[%d]" % [path, w]
		var plain: int = spawn_total(groups, catalog, none)
		if plain > LevelData.SPAWN_BOUND:
			chk.fail(wave_path, "spawns %d creatures; at most %d" % [plain, LevelData.SPAWN_BOUND])
		if int(pack["band"]) == BANDS and w == WAVES - 1:
			continue
		for risk: Variant in risks:
			var card: Dictionary = risk
			var effects: Array[Dictionary] = card["effects"]
			var total: int = spawn_total(groups, catalog, effects)
			if total > LevelData.SPAWN_BOUND:
				chk.fail(wave_path, "with risk card %s spawns %d creatures; at most %d" % [card["id"], total, LevelData.SPAWN_BOUND])


## Creatures one wave spawns, counting split_count for each splitter, with a risk
## card's count_pct and add_group effects (2.8). A count_pct also scales added groups,
## which makes this an upper bound.
static func spawn_total(groups: Array, catalog: Catalog, effects: Array[Dictionary]) -> int:
	var total: int = 0
	for group: Variant in groups:
		var item: Dictionary = group
		total += _group_total(StringName(String(item["enemy"])), int(item["count"]), catalog, effects)
	for effect: Dictionary in effects:
		if effect["type"] == "add_group":
			total += _group_total(StringName(String(effect["enemy"])), int(effect["count"]), catalog, effects)
	return total


static func _group_total(enemy: StringName, count: int, catalog: Catalog, effects: Array[Dictionary]) -> int:
	var type: EnemyType = catalog.enemy(enemy)
	if type == null:
		return 0
	return Modifiers.group_count(effects, count, type.flying, false) * (1 + type.split_count)


## At least 4 packs in every band, and a band 6 pack for every boss.
static func _check_totals(packs: Array[Dictionary], catalog: Catalog, chk: DataCheck) -> void:
	for band: int in range(1, BANDS + 1):
		var count: int = 0
		for pack: Dictionary in packs:
			if pack["band"] == band:
				count += 1
		if count < MIN_PER_BAND:
			chk.fail("packs", "band %d needs at least %d packs; it has %d" % [band, MIN_PER_BAND, count])
	for id: StringName in catalog.enemy_ids():
		var type: EnemyType = catalog.enemy(id)
		if not type.boss:
			continue
		var found: bool = false
		for pack: Dictionary in packs:
			if pack["band"] == BANDS and pack["boss"] == id:
				found = true
				break
		if not found:
			chk.fail("packs", "no band %d pack for the boss %s" % [BANDS, id])
