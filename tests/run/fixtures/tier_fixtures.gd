# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Fixtures for the content tiers (docs/ARCHITECTURE.md 14.8). The real regions 5 to 8 are not
## in the data yet, so these add stand-ins to the real stats and to the run fixtures:
## clones of real towers and creatures under new ids, run.json tiers that list them, cards,
## segments with the map features T and X, and packs that use them. Every fixture here is
## valid. A test copies one with duplicate(true) and breaks one thing.
##
## Tier 1: tower bramble_cottage, creatures mossbud and mistwisp, boss burrowbelly, feature T.
## Tier 2: tower scarecrow, creature gleamer, boss old_hayrick, feature X.

const Fx: GDScript = preload("res://tests/run/fixtures/run_fixtures.gd")

const TIER_1_TOWER: String = "bramble_cottage"
const TIER_2_TOWER: String = "scarecrow"


static func _clone(item: Dictionary, id: String, name: String) -> Dictionary:
	var out: Dictionary = item.duplicate(true)
	out["id"] = id
	out["name"] = name
	return out


## The real stats plus the stand-in towers and creatures. mutate (optional) takes
## {"towers": Dictionary, "enemies": Dictionary, "rules": Dictionary} as plain values and may change them.
static func catalog(mutate: Callable = Callable()) -> Catalog:
	var towers: Dictionary = Fx.read(Fx.STATS_DIR + "towers.json")
	var enemies: Dictionary = Fx.read(Fx.STATS_DIR + "enemies.json")
	var rules: Dictionary = Fx.read(Fx.STATS_DIR + "rules.json")
	# The stand-ins take the place of real entries with the same ids (the real data has them from E5.1 on).
	var stand_ins: Array = [TIER_1_TOWER, TIER_2_TOWER, "mossbud", "mistwisp", "gleamer", "burrowbelly", "old_hayrick"]
	towers["towers"] = (towers["towers"] as Array).filter(func(item: Dictionary) -> bool: return not stand_ins.has(item["id"]))
	enemies["enemies"] = (enemies["enemies"] as Array).filter(func(item: Dictionary) -> bool: return not stand_ins.has(item["id"]))
	var sling: Dictionary = {}
	for item: Dictionary in towers["towers"]:
		if item["id"] == "sling_post":
			sling = item
	for pair: Array in [[TIER_1_TOWER, "Bramble Cottage", "bc"], [TIER_2_TOWER, "Scarecrow", "sc"]]:
		var copy: Dictionary = _clone(sling, pair[0], pair[1])
		copy["plural"] = pair[1] + "s"
		for i: int in 2:
			copy["specs"][i]["id"] = "%s_path_%d" % [pair[2], i]
		towers["towers"].append(copy)
	var by_id: Dictionary = {}
	for item: Dictionary in enemies["enemies"]:
		by_id[item["id"]] = item
	var extra: Array = [
		_clone(by_id["scamp"], "mossbud", "Mossbud"),
		_clone(by_id["flitter"], "mistwisp", "Mistwisp"),
		_clone(by_id["pip"], "gleamer", "Gleamer"),
		_clone(by_id["grumblesack"], "burrowbelly", "Burrowbelly"),
		_clone(by_id["ironshell"], "old_hayrick", "Old Hayrick"),
	]
	extra[3]["summon"]["enemy"] = "mistwisp"
	for item: Dictionary in extra:
		enemies["enemies"].append(item)
	var all: Dictionary = {"towers": towers, "enemies": enemies, "rules": rules}
	if mutate.is_valid():
		mutate.call(all)
	var parsed_towers: Variant = JSON.parse_string(JSON.stringify(all["towers"]))
	var parsed_enemies: Variant = JSON.parse_string(JSON.stringify(all["enemies"]))
	var parsed_rules: Variant = JSON.parse_string(JSON.stringify(all["rules"]))
	return Catalog.from_data(parsed_towers, parsed_enemies, parsed_rules)


static func tiers() -> Array:
	return [
		{"level": "r5_l6", "towers": [TIER_1_TOWER], "creatures": ["mossbud", "mistwisp"], "bosses": ["burrowbelly"], "grid": "T"},
		{"level": "r6_l6", "towers": [TIER_2_TOWER], "creatures": ["gleamer"], "bosses": ["old_hayrick"], "grid": "X"},
	]


static func run_plan() -> Dictionary:
	var plan: Dictionary = Fx.run_plan()
	plan["tiers"] = tiers()
	return plan


static func _replace_cell(rows: Array, row: int, col: int, ch: String) -> Array:
	var out: Array = rows.duplicate()
	var line: String = out[row]
	out[row] = line.substr(0, col) + ch + line.substr(col + 1)
	return out


## Extra segments, in the file shape: a tier 1 middle with a tunnel and a tier 2 middle with a
## bridge. Both are mid_split with one straight road cell changed, so their ports are its ports,
## every top and bottom that fits it fits them, and the road still leads from entrance to base.
static func segments() -> Dictionary:
	var split: Array = Fx.SEGMENTS["mid_split"][1]
	return {
		"mid_tunnel": ["middle", _replace_cell(split, 4, 3, "T")],
		"mid_bridge": ["middle", _replace_cell(split, 0, 3, "X")],
	}


## The fixture index order with the two tier segments in the middle of it.
static func index_order() -> Array:
	var out: Array = Fx.INDEX_ORDER.duplicate()
	out.insert(out.find("mid_split") + 1, "mid_tunnel")
	out.insert(out.find("mid_bend") + 1, "mid_bridge")
	return out


static func _pack(files: Dictionary, id: String) -> Dictionary:
	for item: Variant in files["segments/packs.json"]["packs"]:
		if (item as Dictionary)["id"] == id:
			return item
	return {}


## Packs that use the stand-ins, put first in the file: a tier 1 pack for band 2, a tier 2 pack
## for band 3, and a band 6 pack for each new boss.
static func packs() -> Dictionary:
	var base: Dictionary = Fx.packs()
	var files: Dictionary = {"segments/packs.json": base}
	var made: Array = []
	var one: Dictionary = (_pack(files, "band2_pack0")).duplicate(true)
	one["id"] = "band2_mossbud"
	one["waves"][1]["groups"][0]["enemy"] = "mossbud"
	made.append(one)
	var two: Dictionary = (_pack(files, "band3_pack0")).duplicate(true)
	two["id"] = "band3_gleamer"
	two["waves"][1]["groups"][0]["enemy"] = "gleamer"
	made.append(two)
	var burrow: Dictionary = (_pack(files, "band6_pack0")).duplicate(true)
	burrow["id"] = "band6_burrowbelly"
	burrow["boss"] = "burrowbelly"
	burrow["waves"][2]["groups"][0]["enemy"] = "burrowbelly"
	made.append(burrow)
	var hayrick: Dictionary = (_pack(files, "band6_pack1")).duplicate(true)
	hayrick["id"] = "band6_hayrick"
	hayrick["boss"] = "old_hayrick"
	hayrick["waves"][2]["groups"][0]["enemy"] = "old_hayrick"
	made.append(hayrick)
	var all: Array = made.duplicate()
	all.append_array(base["packs"])
	return {"format": 1, "packs": all}


static func cards() -> Dictionary:
	var out: Dictionary = Fx.cards()
	var list: Array = out["cards"]
	# Between the fixture's own cards, so file order is tested too.
	list.insert(1, Fx.tower_card(TIER_1_TOWER, "Bramble Cottage"))
	list.insert(3, Fx.tower_card(TIER_2_TOWER, "Scarecrow"))
	list.insert(7, {"id": "thorn_tips", "kind": "perk", "tower": TIER_1_TOWER, "name": "Thorn Tips",
		"text": "Bramble Cottages deal 2 more damage.", "once": true, "unlock": {},
		"effects": [{"type": "tower_add", "tower": TIER_1_TOWER, "stat": "damage", "amount": 2}]})
	list.insert(8, {"id": "straw_hats", "kind": "perk", "tower": TIER_2_TOWER, "name": "Straw Hats",
		"text": "Scarecrows reach further.", "once": true, "unlock": {"counter": "stars", "at": 10},
		"effects": [{"type": "tower_add", "tower": TIER_2_TOWER, "stat": "reach", "amount": 50},
			{"type": "tower_add", "tower": TIER_2_TOWER, "stat": "damage", "amount": -1}]})
	return out


## All parsed files after a trip through the JSON parser, with the tiers.
static func files() -> Dictionary:
	var out: Dictionary = {
		"runs/run.json": run_plan(), "cards/cards.json": cards(),
		"segments/index.json": {"format": 1, "segments": index_order()},
		"segments/packs.json": packs(),
	}
	var extra: Dictionary = segments()
	for id: String in index_order():
		if extra.has(id):
			var item: Array = extra[id]
			out["segments/%s.json" % id] = {"format": 1, "id": id, "kind": item[0], "grid": (item[1] as Array).duplicate()}
		else:
			out["segments/%s.json" % id] = Fx.segment(id)
	var parsed: Dictionary = {}
	for key: String in out.keys():
		parsed[key] = JSON.parse_string(JSON.stringify(out[key]))
	return parsed


static func run_data() -> RunData:
	return RunData.from_data(files(), catalog())
