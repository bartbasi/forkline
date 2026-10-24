# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Catalog
extends RefCounted
## data/stats/ checked and held: towers, creatures and core rules
## (docs/ARCHITECTURE.md 2.6). src/save/ reads the files and passes the parsed values in.

const FORMAT: int = 1
const TOWER_KINDS: PackedStringArray = ["attack", "slow", "boost"]
const HITS: PackedStringArray = ["ground", "air", "both"]
const RULE_KEYS: PackedStringArray = [
	"format", "start_lives", "relaxed_lives_pct", "relaxed_gold_pct", "refund_pct",
	"early_bonus_pct", "clear_bonus", "clear_bonus_per_wave", "star2_lives",
	"max_waves_running", "max_gates", "bubble_ms", "region_stars", "run_stars",
]
const ENEMY_REQUIRED: PackedStringArray = ["id", "name", "info", "health", "armor", "speed", "lives", "bounty"]
const ENEMY_OPTIONAL: PackedStringArray = [
	"flying", "boss", "bubble", "heal", "heal_reach", "heal_ms", "split_into", "split_count",
	"split_gap_ms", "break_ms", "summon", "speed_up", "release",
]

var rules: GameRules = null

var _towers: Dictionary[StringName, TowerType] = {}
var _enemies: Dictionary[StringName, EnemyType] = {}
var _tower_ids: Array[StringName] = []
var _enemy_ids: Array[StringName] = []


## Every problem in the three parsed stat files; empty when valid.
static func check(towers: Variant, enemies: Variant, rules_data: Variant) -> PackedStringArray:
	var built: Array = _build(towers, enemies, rules_data)
	return built[1]


## Null when check() finds anything.
static func from_data(towers: Variant, enemies: Variant, rules_data: Variant) -> Catalog:
	var built: Array = _build(towers, enemies, rules_data)
	var problems: PackedStringArray = built[1]
	if not problems.is_empty():
		return null
	return built[0]


func tower(id: StringName) -> TowerType:
	return _towers.get(id, null)


func enemy(id: StringName) -> EnemyType:
	return _enemies.get(id, null)


func tower_ids() -> Array[StringName]:
	return _tower_ids.duplicate()


func enemy_ids() -> Array[StringName]:
	return _enemy_ids.duplicate()


func has_tower(id: StringName) -> bool:
	return _towers.has(id)


func has_enemy(id: StringName) -> bool:
	return _enemies.has(id)


## [Catalog, PackedStringArray of problems].
static func _build(towers: Variant, enemies: Variant, rules_data: Variant) -> Array:
	var catalog: Catalog = new()
	var problems: PackedStringArray = PackedStringArray()
	var tower_check: DataCheck = DataCheck.new("towers.json")
	catalog._read_towers(towers, tower_check)
	problems.append_array(tower_check.problems)
	var enemy_check: DataCheck = DataCheck.new("enemies.json")
	catalog._read_enemies(enemies, enemy_check)
	problems.append_array(enemy_check.problems)
	var rule_check: DataCheck = DataCheck.new("rules.json")
	catalog._read_rules(rules_data, rule_check)
	problems.append_array(rule_check.problems)
	return [catalog, problems]


func _read_towers(data: Variant, chk: DataCheck) -> void:
	if not chk.object(data, "", ["format", "towers"]):
		return
	var top: Dictionary = data
	chk.integer(top, "format", "", FORMAT, FORMAT)
	var list: Array = chk.array(top, "towers", "", 1, 32)
	var spec_ids: Dictionary = {}
	for i: int in list.size():
		var path: String = "towers[%d]" % i
		if not chk.object(list[i], path, ["id", "name", "plural", "info", "kind", "tiers", "specs"]):
			continue
		var item: Dictionary = list[i]
		var type: TowerType = TowerType.new()
		type.id = chk.ident(item, "id", path)
		type.name = chk.text(item, "name", path, 24)
		type.plural = chk.text(item, "plural", path, 24)
		type.info = chk.text(item, "info", path, 80)
		var kind_value: Variant = item.get("kind", "")
		if not DataCheck.is_string(kind_value) or not TOWER_KINDS.has(String(kind_value)):
			chk.fail(DataCheck.join(path, "kind"), "must be attack, slow or boost")
			continue
		type.kind = StringName(String(kind_value))
		var tiers: Array = chk.array(item, "tiers", path, 2, 2)
		for t: int in tiers.size():
			type._tiers.append(_read_stats(tiers[t], "%s.tiers[%d]" % [path, t], type.kind, false, chk))
		var specs: Array = chk.array(item, "specs", path, 2, 2)
		for s: int in specs.size():
			var spec_path: String = "%s.specs[%d]" % [path, s]
			type._spec_stats.append(_read_stats(specs[s], spec_path, type.kind, true, chk))
			if typeof(specs[s]) != TYPE_DICTIONARY:
				continue
			var spec: Dictionary = specs[s]
			var spec_id: StringName = chk.ident(spec, "id", spec_path)
			if spec_id != &"" and spec_ids.has(spec_id):
				chk.fail(DataCheck.join(spec_path, "id"), "repeats %s" % spec_id)
			spec_ids[spec_id] = true
			type.specs.append(spec_id)
			type._spec_names.append(chk.text(spec, "name", spec_path, 24))
			type._spec_infos.append(chk.text(spec, "info", spec_path, 80))
		if type.id == &"":
			continue
		if _towers.has(type.id):
			chk.fail(DataCheck.join(path, "id"), "repeats %s" % type.id)
			continue
		_towers[type.id] = type
		_tower_ids.append(type.id)


func _read_stats(data: Variant, path: String, kind: StringName, is_spec: bool, chk: DataCheck) -> TowerStats:
	var stats: TowerStats = TowerStats.new()
	var required: PackedStringArray = ["cost", "reach"]
	var optional: PackedStringArray = PackedStringArray()
	match kind:
		&"attack":
			required.append_array(["hits", "damage", "reload_ms"])
			optional.append_array(["splash", "targets", "pierce", "slow_pct", "slow_ms"])
		&"slow":
			required.append_array(["hits", "slow_pct", "slow_ms"])
		&"boost":
			required.append("boost_pct")
			optional.append("boost_damage")
	if is_spec:
		required.append_array(["id", "name", "info"])
	if not chk.object(data, path, required, optional):
		return stats
	var item: Dictionary = data
	stats.cost = chk.integer(item, "cost", path, 10, 100000, 10)
	stats.reach = chk.integer(item, "reach", path, 1, 1000)
	if item.has("hits"):
		var hits: Variant = item["hits"]
		if not DataCheck.is_string(hits) or not HITS.has(String(hits)):
			chk.fail(DataCheck.join(path, "hits"), "must be ground, air or both")
		else:
			stats.hits_ground = String(hits) != "air"
			stats.hits_air = String(hits) != "ground"
	stats.damage = chk.integer(item, "damage", path, 1, 100000)
	stats.reload_ms = chk.integer(item, "reload_ms", path, 50, 60000, 50)
	stats.splash = chk.integer(item, "splash", path, 0, 500)
	stats.targets = chk.integer(item, "targets", path, 1, 3, 1, 1)
	stats.pierce = chk.boolean(item, "pierce", path)
	stats.slow_pct = chk.integer(item, "slow_pct", path, 1, 90)
	stats.slow_ms = chk.integer(item, "slow_ms", path, 50, 60000, 50)
	if item.has("slow_pct") != item.has("slow_ms"):
		chk.fail(path, "slow_pct and slow_ms come together")
	stats.boost_pct = chk.integer(item, "boost_pct", path, 0, 500)
	stats.boost_damage = chk.integer(item, "boost_damage", path, 0, 1000)
	return stats


func _read_enemies(data: Variant, chk: DataCheck) -> void:
	if not chk.object(data, "", ["format", "enemies"]):
		return
	var top: Dictionary = data
	chk.integer(top, "format", "", FORMAT, FORMAT)
	var list: Array = chk.array(top, "enemies", "", 1, 64)
	var paths: Dictionary[StringName, String] = {}
	for i: int in list.size():
		var path: String = "enemies[%d]" % i
		if not chk.object(list[i], path, ENEMY_REQUIRED, ENEMY_OPTIONAL):
			continue
		var item: Dictionary = list[i]
		var type: EnemyType = EnemyType.new()
		type.id = chk.ident(item, "id", path)
		type.name = chk.text(item, "name", path, 24)
		type.info = chk.text(item, "info", path, 80)
		type.health = chk.integer(item, "health", path, 1, 1000000, 1, 1)
		type.armor = chk.integer(item, "armor", path, 0, 1000)
		type.speed = chk.integer(item, "speed", path, 1, 1000, 1, 1)
		type.lives = chk.integer(item, "lives", path, 1, 1000, 1, 1)
		type.bounty = chk.integer(item, "bounty", path, 1, 100000, 1, 1)
		type.flying = chk.boolean(item, "flying", path)
		type.boss = chk.boolean(item, "boss", path)
		type.bubble = chk.boolean(item, "bubble", path)
		type.heal = chk.integer(item, "heal", path, 1, 10000)
		type.heal_reach = chk.integer(item, "heal_reach", path, 1, 1000)
		type.heal_ms = chk.integer(item, "heal_ms", path, 50, 600000, 50)
		if item.has("heal") != item.has("heal_reach") or item.has("heal") != item.has("heal_ms"):
			chk.fail(path, "heal, heal_reach and heal_ms come together")
		type.split_into = chk.ident(item, "split_into", path)
		type.split_count = chk.integer(item, "split_count", path, 1, 10)
		type.split_gap_ms = chk.integer(item, "split_gap_ms", path, 50, 60000, 50)
		if item.has("split_into") != item.has("split_count") or item.has("split_into") != item.has("split_gap_ms"):
			chk.fail(path, "split_into, split_count and split_gap_ms come together")
		type.break_ms = chk.integer(item, "break_ms", path, 50, 600000, 50)
		if item.has("summon"):
			var summon_path: String = DataCheck.join(path, "summon")
			if chk.object(item["summon"], summon_path, ["enemy", "count", "every_ms", "gap_ms"]):
				var summon: Dictionary = item["summon"]
				type.summon = {
					"enemy": chk.ident(summon, "enemy", summon_path),
					"count": chk.integer(summon, "count", summon_path, 1, 20, 1, 1),
					"every_ms": chk.integer(summon, "every_ms", summon_path, 50, 600000, 50, 50),
					"gap_ms": chk.integer(summon, "gap_ms", summon_path, 50, 60000, 50, 50),
				}
		if item.has("speed_up"):
			var up_path: String = DataCheck.join(path, "speed_up")
			if chk.object(item["speed_up"], up_path, ["at_pct", "add"]):
				var up: Dictionary = item["speed_up"]
				var at_list: Array = chk.array(up, "at_pct", up_path, 1, 10)
				var at_pct: Array[int] = []
				for k: int in at_list.size():
					var pct: int = chk.whole(at_list[k], "%s.at_pct[%d]" % [up_path, k], 1, 99, 1, 1)
					if not at_pct.is_empty() and pct >= at_pct.back():
						chk.fail("%s.at_pct[%d]" % [up_path, k], "must be lower than the one before")
					at_pct.append(pct)
				type.speed_up = {"at_pct": at_pct, "add": chk.integer(up, "add", up_path, 1, 1000, 1, 1)}
		if item.has("release"):
			var rel_path: String = DataCheck.join(path, "release")
			if chk.object(item["release"], rel_path, ["at_pct", "enemy", "count", "gap_ms"]):
				var rel: Dictionary = item["release"]
				type.release = {
					"at_pct": chk.integer(rel, "at_pct", rel_path, 1, 99, 1, 1),
					"enemy": chk.ident(rel, "enemy", rel_path),
					"count": chk.integer(rel, "count", rel_path, 1, 20, 1, 1),
					"gap_ms": chk.integer(rel, "gap_ms", rel_path, 50, 60000, 50, 50),
				}
		if type.id == &"":
			continue
		if _enemies.has(type.id):
			chk.fail(DataCheck.join(path, "id"), "repeats %s" % type.id)
			continue
		_enemies[type.id] = type
		_enemy_ids.append(type.id)
		paths[type.id] = path
	# Cross references, once every id is known. A released creature never releases
	# others itself, so releases cannot chain, and a flyer releases only flyers
	# (a walker needs a road step to start from, RULES 6.2).
	for id: StringName in _enemy_ids:
		var type: EnemyType = _enemies[id]
		var path: String = paths[id]
		if type.split_into != &"":
			_check_released(type, type.split_into, DataCheck.join(path, "split_into"), chk)
		if not type.summon.is_empty():
			_check_released(type, type.summon["enemy"], DataCheck.join(path, "summon.enemy"), chk)
		if not type.release.is_empty():
			_check_released(type, type.release["enemy"], DataCheck.join(path, "release.enemy"), chk)


func _check_released(releaser: EnemyType, id: StringName, path: String, chk: DataCheck) -> void:
	if id == &"":
		return
	var released: EnemyType = _enemies.get(id, null)
	if released == null:
		chk.fail(path, "names no creature")
		return
	if released.id == releaser.id:
		chk.fail(path, "cannot release itself")
		return
	if released.split_into != &"" or not released.summon.is_empty() or not released.release.is_empty():
		chk.fail(path, "a released creature cannot release others")
	if released.boss:
		chk.fail(path, "a boss cannot be released")
	if releaser.flying and not released.flying:
		chk.fail(path, "a flyer can release only flyers")


func _read_rules(data: Variant, chk: DataCheck) -> void:
	if not chk.object(data, "", RULE_KEYS):
		return
	var top: Dictionary = data
	var r: GameRules = GameRules.new()
	chk.integer(top, "format", "", FORMAT, FORMAT)
	r.start_lives = chk.integer(top, "start_lives", "", 1, 1000, 1, 1)
	r.relaxed_lives_pct = chk.integer(top, "relaxed_lives_pct", "", 100, 1000, 1, 100)
	r.relaxed_gold_pct = chk.integer(top, "relaxed_gold_pct", "", 100, 1000, 1, 100)
	r.refund_pct = chk.integer(top, "refund_pct", "", 0, 100)
	r.early_bonus_pct = chk.integer(top, "early_bonus_pct", "", 0, 100)
	r.clear_bonus = chk.integer(top, "clear_bonus", "", 0, 10000)
	r.clear_bonus_per_wave = chk.integer(top, "clear_bonus_per_wave", "", 0, 1000)
	r.star2_lives = chk.integer(top, "star2_lives", "", 1, r.start_lives, 1, 1)
	r.max_waves_running = chk.integer(top, "max_waves_running", "", 1, 10, 1, 1)
	r.max_gates = chk.integer(top, "max_gates", "", 0, 8)
	r.bubble_ms = chk.integer(top, "bubble_ms", "", 50, 60000, 50, 50)
	var stars: Array = chk.array(top, "region_stars", "", 1, 8)
	for i: int in stars.size():
		var count: int = chk.whole(stars[i], "region_stars[%d]" % i, 0, 1000)
		if not r.region_stars.is_empty() and count < r.region_stars.back():
			chk.fail("region_stars[%d]" % i, "must not be lower than the one before")
		r.region_stars.append(count)
	r.run_stars = chk.integer(top, "run_stars", "", 0, 1000)
	rules = r
