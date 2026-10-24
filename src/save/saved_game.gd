# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name SavedGame
extends RefCounted
## One level or run in progress, saved at the exact moment (docs/ARCHITECTURE.md 3.5, 5.5, 5.6, 6).
## One saved game per mode (Bart, hard stop A).

const FORMAT: int = 1
const LEVEL: StringName = &"level"
const RUN: StringName = &"run"
const DAILY: StringName = &"daily"
const MODES: Array[StringName] = [LEVEL, RUN, DAILY]
const ORDER_MAX: int = 1000000000000
const KEYS: PackedStringArray = ["format", "mode", "order", "level_id", "twist", "battle", "run"]

var mode: StringName = LEVEL                           # &"level", &"run" or &"daily"
var order: int = 0                                     # higher is more recent; SaveStore sets it
var level_id: StringName = &""                         # the campaign level; &"" for runs
var twist: bool = false
var battle: Battle = null


## The file shape. The run session joins in phase 7; until then "run" is null.
func to_data() -> Dictionary:
	return {
		"format": FORMAT, "mode": String(mode), "order": order, "level_id": String(level_id),
		"twist": twist, "battle": battle.to_data() if battle != null else {}, "run": null,
	}


## True when this game can be saved: a known mode and a battle still being played.
func can_save() -> bool:
	return MODES.has(mode) and battle != null and (battle.phase == Battle.Phase.BUILD or battle.phase == Battle.Phase.WAVE)


## Null when any field is invalid. All or nothing.
static func from_data(data: Variant, game: GameData) -> SavedGame:
	if game == null or game.catalog == null:
		return null
	var chk: DataCheck = DataCheck.new("saved game")
	if not chk.object(data, "", KEYS) or not chk.ok():
		return null
	var top: Dictionary = data
	var saved: SavedGame = new()
	chk.integer(top, "format", "", FORMAT, FORMAT)
	var mode_value: Variant = top["mode"]
	if not DataCheck.is_string(mode_value) or not MODES.has(StringName(String(mode_value))):
		return null
	saved.mode = StringName(String(mode_value))
	saved.order = chk.integer(top, "order", "", 0, ORDER_MAX)
	saved.twist = chk.boolean(top, "twist", "")
	if top["run"] != null:
		chk.fail("run", "runs are saved from phase 7")
	var id_value: Variant = top["level_id"]
	if saved.mode == LEVEL:
		saved.level_id = chk.ident(top, "level_id", "")
		if not game.levels.has(saved.level_id):
			chk.fail("level_id", "must be a campaign level")
	elif not DataCheck.is_string(id_value) or not String(id_value).is_empty():
		chk.fail("level_id", "must be empty for a run")
	if saved.twist and (saved.mode != LEVEL or not game.levels.has(saved.level_id) or game.levels[saved.level_id].twist_effects.is_empty()):
		chk.fail("twist", "must name a level with a Twist")
	if not chk.ok():
		return null
	saved.battle = Battle.from_data(top["battle"], game.catalog)
	if saved.battle == null:
		return null
	if saved.mode == LEVEL and saved.battle.level.id != saved.level_id:
		return null
	if saved.mode == DAILY and saved.battle.relaxed:
		return null
	return saved
