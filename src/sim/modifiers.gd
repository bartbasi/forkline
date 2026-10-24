# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Modifiers
extends RefCounted
## Twist, card and risk effects (docs/ARCHITECTURE.md 2.8). Only check() is public to
## other areas. Phase 5 checks every effect type; Battle applies none of them yet
## (Twists and cards come in phase 7).

const USES: PackedStringArray = ["twist", "card", "risk"]
const TOWER_ADD_STATS: PackedStringArray = [
	"damage", "reload_ms", "reach", "splash", "slow_pct", "targets", "boost_pct", "boost_damage",
]
const TOWER_PCT_STATS: PackedStringArray = ["damage", "reload_ms"]
const MAX_FIXED_CELLS: int = 8

## type: [uses, {field: rule}]. Rules: pct 1 to 1,000; refund 1 to 100 (4.6); count 1 to 200; gates 0 to
## max_gates; lives 1 to 1,000; cells; tower and enemy ids; tier 1 or 2; bool;
## time (a multiple of 50 up to 600,000); every (50 to 600,000); entrance 1 to 4;
## number -1,000 to 1,000; add_stat and pct_stat (stat names).
const TYPES: Dictionary = {
	"start_gold_pct": [["twist"], {"pct": "pct"}],
	"set_lives": [["twist"], {"lives": "lives"}],
	"set_gates": [["twist"], {"count": "gates"}],
	"fixed_gates": [["twist"], {"cells": "cells"}],
	"ban_tower": [["twist"], {"tower": "tower"}],
	"tier_cap": [["twist"], {"tier": "tier"}],
	"no_selling": [["twist"], {}],
	"count_pct": [["twist", "risk"], {"pct": "pct", "flyers": "bool", "last_wave": "bool"}],
	"health_pct": [["risk"], {"pct": "pct"}],
	"speed_pct": [["twist", "risk"], {"pct": "pct"}],
	"armor_add": [["twist"], {"amount": "number"}],
	"all_bubbles": [["twist"], {}],
	"break_ms": [["twist"], {"enemy": "enemy", "ms": "time"}],
	"gates_open": [["risk"], {}],
	"add_group": [["risk"], {"enemy": "enemy", "count": "count", "entrance": "entrance",
		"at_ms": "time", "every_ms": "every", "after_last": "bool"}],
	"reward_gold": [["risk"], {"amount": "number"}],
	"add_tower": [["card"], {"tower": "tower"}],
	"tower_add": [["card"], {"tower": "tower", "stat": "add_stat", "amount": "number"}],
	"tower_pct": [["card"], {"tower": "tower", "stat": "pct_stat", "pct": "pct"}],
	"tower_hits_air": [["card"], {"tower": "tower"}],
	"bounty_pct": [["card"], {"pct": "pct"}],
	"clear_bonus_pct": [["card"], {"pct": "pct"}],
	"refund_pct": [["card"], {"pct": "refund"}],
	"cost_add": [["card"], {"build": "number", "upgrade": "number"}],
	"interest": [["card"], {"pct": "pct", "max": "number"}],
	"gates_stay": [["card"], {}],
	"add_gates": [["card"], {"count": "count"}],
	"add_gold": [["card"], {"amount": "number", "per_wave": "number"}],
	"add_lives": [["card"], {"amount": "number"}],
}


## Every problem in a list of effects for one use (&"twist", &"card" or &"risk").
static func check(effects: Variant, catalog: Catalog, use: StringName) -> PackedStringArray:
	var chk: DataCheck = DataCheck.new()
	if catalog == null or catalog.rules == null:
		chk.fail("effects", "needs a valid catalog")
		return chk.problems
	if not USES.has(String(use)):
		chk.fail("effects", "unknown use %s" % String(use).left(DataCheck.ID_MAX))
		return chk.problems
	var list: Array = chk.array_value(effects, "effects", 0, 64)
	for i: int in list.size():
		_check_one(list[i], "effects[%d]" % i, catalog, String(use), chk)
	return chk.problems


static func _check_one(data: Variant, path: String, catalog: Catalog, use: String, chk: DataCheck) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		chk.fail(path, "must be an object")
		return
	var effect: Dictionary = data
	var type_value: Variant = effect.get("type", null)
	if not DataCheck.is_string(type_value) or not TYPES.has(String(type_value)):
		chk.fail(DataCheck.join(path, "type"), "must be a known effect type")
		return
	var type: String = String(type_value)
	var spec: Array = TYPES[type]
	var uses: Array = spec[0]
	if not uses.has(use):
		chk.fail(DataCheck.join(path, "type"), "%s is not allowed for a %s" % [type, use])
	var fields: Dictionary = spec[1]
	var keys: PackedStringArray = ["type"]
	for key: String in fields.keys():
		keys.append(key)
	if not chk.object(effect, path, keys):
		return
	for key: String in fields.keys():
		if not effect.has(key):
			continue
		var field_path: String = DataCheck.join(path, key)
		var value: Variant = effect[key]
		match String(fields[key]):
			"pct":
				chk.whole(value, field_path, 1, 1000)
			"refund":
				chk.whole(value, field_path, 1, 100)       # 4.6: selling never makes a profit
			"count":
				chk.whole(value, field_path, 1, 200)
			"gates":
				chk.whole(value, field_path, 0, catalog.rules.max_gates)
			"lives":
				chk.whole(value, field_path, 1, 1000)
			"tier":
				chk.whole(value, field_path, 1, 2)
			"entrance":
				chk.whole(value, field_path, 1, Sim.MAX_ENTRANCES)
			"time":
				chk.whole(value, field_path, 0 if key == "at_ms" else 50, 600000, 50)
			"every":
				chk.whole(value, field_path, 50, 600000, 50)
			"number":
				chk.whole(value, field_path, -1000, 1000)
			"bool":
				if typeof(value) != TYPE_BOOL:
					chk.fail(field_path, "must be true or false")
			"tower":
				if chk.ident_value(value, field_path) != &"" and not catalog.has_tower(StringName(String(value))):
					chk.fail(field_path, "names no tower")
			"enemy":
				if chk.ident_value(value, field_path) != &"" and not catalog.has_enemy(StringName(String(value))):
					chk.fail(field_path, "names no creature")
			"add_stat":
				if not DataCheck.is_string(value) or not TOWER_ADD_STATS.has(String(value)):
					chk.fail(field_path, "must be a stat a card can add to")
			"pct_stat":
				if not DataCheck.is_string(value) or not TOWER_PCT_STATS.has(String(value)):
					chk.fail(field_path, "must be damage or reload_ms")
			"cells":
				var cells: Array = chk.array_value(value, field_path, 1, MAX_FIXED_CELLS)
				var seen: Array[Vector2i] = []
				for k: int in cells.size():
					var cell: Vector2i = chk.cell(cells[k], "%s[%d]" % [field_path, k], Sim.MAP_ROWS_MAX)
					if seen.has(cell):
						chk.fail("%s[%d]" % [field_path, k], "repeats a cell")
					seen.append(cell)
	var last_wave: Variant = effect.get("last_wave", false)
	if type == "count_pct" and use != "twist" and typeof(last_wave) == TYPE_BOOL and last_wave:
		chk.fail(DataCheck.join(path, "last_wave"), "is for Twists only")


## Checked effects as plain data: ints, bools, Strings and [column, row] cells.
static func normalize_all(effects: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for data: Variant in effects:
		var effect: Dictionary = data
		var clean: Dictionary = {}
		for key: String in effect.keys():
			clean[key] = _plain(effect[key])
		out.append(clean)
	return out


static func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return int(value)
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_plain(item))
			return out
	return value


## The cells of every fixed_gates effect, in cell order, without repeats.
static func fixed_cells(effects: Array[Dictionary]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for effect: Dictionary in effects:
		if effect.get("type", "") != "fixed_gates":
			continue
		for pair: Variant in effect["cells"]:
			var cell: Vector2i = Vector2i(int(pair[0]), int(pair[1]))
			if not cells.has(cell):
				cells.append(cell)
	cells.sort_custom(Sim.cell_before)
	return cells


## A group's count with every count_pct effect applied, rounded up (2.8).
static func group_count(effects: Array[Dictionary], count: int, flying: bool, last_wave: bool) -> int:
	var result: int = count
	for effect: Dictionary in effects:
		if effect.get("type", "") != "count_pct":
			continue
		if effect["flyers"] and not flying:
			continue
		if effect["last_wave"] and not last_wave:
			continue
		result = Sim.pct_up(result, effect["pct"])
	return result
