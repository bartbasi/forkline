# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Turns the JSON files of one run_region1.sh run into the markdown tables used in the report,
## so no number in a report is typed by hand.
##
##   godot --headless --path . --script res://tools/balance/summary.gd -- dir=res://docs/balance/raw/2026-10-23
##
## It prints markdown to the console. It reads only files this tool wrote.

const LEVELS: Array[String] = ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6"]
const BUILD_SECONDS: int = 15

var _dir: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("dir="):
			_dir = argument.trim_prefix("dir=")
	_economy_table()
	_recipe_tables()
	_spread_tables()
	_search_tables()
	_single_tables()
	_coverage_table()
	_length_table()
	_boss_table()
	_peak_table()
	_det_table()
	_bench_table()
	_died_table()
	_whatif_tables()
	_stats_table()
	_spot_table()
	_builds()
	quit(0)


func _read(name: String) -> Dictionary:
	var path: String = _dir.path_join(name)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _pct(part: int, whole: int) -> String:
	return "-" if whole == 0 else "%d%%" % int(round(100.0 * part / whole))


func _row(cells: Array) -> void:
	var text: String = "|"
	for cell: Variant in cells:
		if cell is float and is_equal_approx(float(cell), floorf(float(cell))):
			text += " %d |" % int(cell)
		else:
			text += " %s |" % str(cell)
	print(text)


func _head(cells: Array) -> void:
	_row(cells)
	var line: Array = []
	for cell: Variant in cells:
		line.append("---")
	_row(line)


## RULES 12.5: a wave's health against the gold a player could have by then (the guide says 0.8).
func _economy_table() -> void:
	var game: GameData = GameData.load_from("res://data")
	print("
### Wave health against gold available (RULES 12.5 guide: about 0.8)
")
	_head(["Level", "Wave", "Creatures", "Total health", "Gold available before it", "Health / gold"])
	for id: String in LEVELS:
		var level: LevelData = game.levels[StringName(id)]
		var gold: int = level.start_gold
		for w: int in level.waves.size():
			var wave: WaveData = level.waves[w]
			var count: int = 0
			var health: int = 0
			var bounty: int = 0
			for group: WaveGroup in wave.groups:
				var type: EnemyType = game.catalog.enemy(group.enemy)
				count += group.count
				health += group.count * maxi(1, (type.health * wave.strength + 50) / 100)
				bounty += group.count * maxi(1, (type.bounty * wave.strength + 50) / 100)
			_row([id, w + 1, count, health, gold, "%.2f" % (float(health) / gold)])
			gold += bounty + (20 + 5 * (w + 1)) * wave.strength / 100


func _recipe_tables() -> void:
	print("
### Plain recipes: how many of them win (a recipe is tried with no gate and with a gate on each socket)
")
	_head(["Level", "Recipes", "Normal: win with every gate choice", "Normal: win with some gate choice", "Relaxed: win with every gate choice", "Relaxed: win with some gate choice"])
	for id: String in LEVELS:
		var d0: Dictionary = _read(id + "_recipes.json")
		if d0.is_empty():
			continue
		var counts: Array[int] = [0, 0, 0, 0]
		for r0: Dictionary in d0["recipes"]:
			var nm: Dictionary = r0["summary"]["normal"]
			var rm: Dictionary = r0["summary"]["relaxed"]
			counts[0] += 1 if int(nm["wins"]) == int(nm["gates_tried"]) else 0
			counts[1] += 1 if int(nm["wins"]) > 0 else 0
			counts[2] += 1 if int(rm["wins"]) == int(rm["gates_tried"]) else 0
			counts[3] += 1 if int(rm["wins"]) > 0 else 0
		_row([id, (d0["recipes"] as Array).size(), counts[0], counts[1], counts[2], counts[3]])
	print("
### Plain recipes (no targeting, no early calls, no buying during waves). Stars won, best gate choice / worst gate choice
")
	_head(["Level", "Recipe", "Normal best gate", "Normal worst gate", "Relaxed best gate", "Relaxed worst gate"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_recipes.json")
		if d.is_empty():
			continue
		for r: Dictionary in d["recipes"]:
			var cells: Array = [id, r["recipe"]]
			for mode: String in ["normal", "relaxed"]:
				for which: String in ["best", "worst"]:
					cells.append(_outcome(r["summary"][mode][which], mode == "relaxed"))
			_row(cells)


func _outcome(res: Dictionary, relaxed: bool) -> String:
	if not bool(res["won"]):
		return "lost (wave %d), gate %s" % [int(res["cleared"]) + 1, res["gate"]]
	var stars: int = 1
	var bits: int = int(res["stars"])
	if (bits & 2) != 0:
		stars += 1
	if (bits & 4) != 0:
		stars += 1
	return "won %d star%s, %d lives, gate %s" % [stars, "" if stars == 1 else "s", int(res["lives"]), res["gate"]]


func _spread_tables() -> void:
	print("\n### Spread: win, two star and three star rates of random strategies (Normal)\n")
	_head(["Level", "Style", "Plays", "Won", "Keep 15 lives (2 stars)", "Three stars", "Mean lives left in a win"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var all: Dictionary = {"n": 0, "won": 0, "two": 0, "three": 0, "lives_sum": 0}
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = d["styles"][style]["normal"]
			_row([id, style, int(t["n"]), _pct(int(t["won"]), int(t["n"])), _pct(int(t["two"]), int(t["n"])),
				_pct(int(t["three"]), int(t["n"])), "-" if int(t["won"]) == 0 else "%.1f" % (float(t["lives_sum"]) / int(t["won"]))])
			for key: String in all:
				all[key] = int(all[key]) + int(t[key])
		_row([id, "**all**", all["n"], _pct(int(all["won"]), int(all["n"])), _pct(int(all["two"]), int(all["n"])),
			_pct(int(all["three"]), int(all["n"])), "-" if int(all["won"]) == 0 else "%.1f" % (float(all["lives_sum"]) / int(all["won"]))])
	print("\n### Spread on Relaxed (40 lives, 1.5 times gold): win rate\n")
	_head(["Level", "casual", "typical", "skilled", "all"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var cells: Array = [id]
		var n: int = 0
		var w: int = 0
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = d["styles"][style]["relaxed"]
			cells.append(_pct(int(t["won"]), int(t["n"])))
			n += int(t["n"])
			w += int(t["won"])
		cells.append(_pct(w, n))
		_row(cells)
	print("\n### Win rate by number of towers built (Normal | Relaxed), all styles\n")
	_head(["Level", "1", "2", "3", "4", "5", "6", "7"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var cells: Array = [id]
		for k: int in range(1, 8):
			var a: Dictionary = d["by_tower_count"].get("normal|%d_towers" % k, {})
			var b: Dictionary = d["by_tower_count"].get("relaxed|%d_towers" % k, {})
			if a.is_empty():
				cells.append("-")
			else:
				cells.append("%s (n=%d) \\| %s" % [_pct(int(a["won"]), int(a["n"])), int(a["n"]), _pct(int(b["won"]), int(b["n"]))])
		_row(cells)
	print("\n### Normal win rate by share of Sling Posts in the build, all styles\n")
	_head(["Level", "0-24% Sling", "25-49%", "50-74%", "75-99%", "100%"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var cells: Array = [id]
		# The bins count the share of the first offered tower (the Sling Post) in quarters.
		for q: int in 5:
			var a: Dictionary = d["by_first_tower_share"].get("normal|sling_post_quarters_%d" % q, {})
			cells.append("-" if a.is_empty() else "%s (n=%d)" % [_pct(int(a["won"]), int(a["n"])), int(a["n"])])
		_row(cells)


func _search_tables() -> void:
	print("\n### Search: best builds found (any tower, Normal)\n")
	_head(["Level", "Builds tried", "Wins", "Three-star wins", "Tried before the first three-star win", "Best lives left"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
		if d.is_empty():
			continue
		var best: int = 0
		if d.has("best_win"):
			best = int(d["best_win"]["result"]["lives"])
		_row([id, d["evals"], d["wins"], d["three_star_found"], d["first_three_star_eval"], best])


func _single_tables() -> void:
	print("\n### One tower type alone (search, Normal)\n")
	_head(["Level", "Only", "Builds tried", "Wins", "Three-star wins", "Best result found"])
	for id: String in LEVELS:
		for only: String in ["sling_post", "pumpkin_catapult"]:
			var d: Dictionary = _read("%s_search_%s.json" % [id, only])
			if d.is_empty():
				continue
			var best: String = "no win"
			if d.has("top"):
				var r: Dictionary = d["top"]["result"]
				if bool(r["won"]):
					var stars: int = int(r["stars"])
					best = "won, %d lives left, %s" % [int(r["lives"]), "3 stars" if stars == 7 else ("2 stars" if (stars & 2) != 0 else "1 star")]
				else:
					best = "lost after %d of %d waves cleared" % [int(r["cleared"]), 0 if not r.has("waves") else int(r["waves"])]
			_row([id, only, d["evals"], d["wins"], d["three_star_found"], best])


func _coverage_table() -> void:
	print("\n### Towers and paths in the three-star wins found (any-tower search): builds using each\n")
	var keys: Array[String] = ["sling_post", "quickshot", "stone_sling", "pumpkin_catapult", "prize_pumpkin", "jam_pot"]
	var head: Array = ["Level", "Three-star wins"]
	head.append_array(keys)
	_head(head)
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
		if d.is_empty():
			continue
		var use: Dictionary = d["three_star_builds_using"]
		var cells: Array = [id, d["three_star_found"]]
		for key: String in keys:
			cells.append(int(use.get(key, 0)))
		_row(cells)


func _length_table() -> void:
	print("
### Length at 1x with no early calls: wave time plus 15 s for each build phase (one before each wave)
")
	_head(["Level", "Waves", "Best build with early calls off: result", "Wave time", "Total", "Casual wins, mean wave time", "Total", "Typical wins, mean wave time", "Total"])
	var game: GameData = GameData.load_from("res://data")
	for id: String in LEVELS:
		var bench: Dictionary = _read(id + "_bench.json")
		var sp: Dictionary = _read(id + "_spread.json")
		var waves: int = game.levels[StringName(id)].waves.size()
		var cells: Array = [id, waves]
		if bench.is_empty():
			cells.append_array(["-", "-", "-"])
		else:
			var row: Dictionary = bench["rows"][0]
			var bits: int = int(row["calm_stars"])
			var stars: int = 1 + (1 if (bits & 2) != 0 else 0) + (1 if (bits & 4) != 0 else 0)
			cells.append("won, %d lives, %d stars" % [int(row["calm_lives"]), stars] if bool(row["calm_won"]) else "lost")
			var secs: float = float(row["calm_ticks"]) / 20.0
			cells.append("%d s" % int(secs))
			cells.append("%.1f min" % ((secs + BUILD_SECONDS * waves) / 60.0))
		for style: String in ["casual", "typical"]:
			var t: Dictionary = sp.get("styles", {}).get(style, {}).get("normal", {})
			if t.is_empty() or int(t["won"]) == 0:
				cells.append("-")
				cells.append("-")
			else:
				var secs2: float = float(t["ticks_sum"]) / int(t["won"]) / 20.0
				cells.append("%d s" % int(secs2))
				cells.append("%.1f min" % ((secs2 + BUILD_SECONDS * waves) / 60.0))
		_row(cells)


func _boss_table() -> void:
	var d: Dictionary = _read("r1_l6_search_any.json")
	if d.is_empty():
		return
	print("
### Level 1-6: the best three-star builds found, and how close the boss got
")
	_head(["Build", "Gold put into towers before the boss wave", "Gold in hand then", "Early calls", "Boss health at its lowest sample", "Boss road steps left at the closest sample", "Lives left"])
	var n: int = 0
	for item: Dictionary in d.get("three_star_best", []):
		var r: Dictionary = item["result"]
		var last: int = (r["spent_at"] as Array).size() - 1
		n += 1
		_row([n, r["spent_at"][last], r["gold_at"][last], r["early"], r["boss_hp"], r["boss_steps"], r["lives"]])
	print("
### Level 1-6: gold and lives before each wave in the highest scoring win (not necessarily build 1 above)
")
	var r1: Dictionary = d["best_win"]["result"]
	_head(["Wave", "Gold in hand", "Gold put into towers so far", "Lives"])
	var gold: Array = r1["gold_at"]
	var spent: Array = r1["spent_at"]
	var lives: Array = r1["lives_at"]
	for i: int in gold.size():
		_row([i + 1, gold[i], spent[i], lives[i]])
	print("
### Plays that reached the final wave, and how many of those won (spread, Normal | Relaxed)
")
	_head(["Level", "Plays", "Reached the final wave", "Won", "Won, as a share of those that reached it"])
	for id: String in ["r1_l5", "r1_l6"]:
		var sp: Dictionary = _read(id + "_spread.json")
		if sp.is_empty():
			continue
		for mode: String in ["normal", "relaxed"]:
			var n_all: int = 0
			var f_all: int = 0
			var w_all: int = 0
			for style: String in ["casual", "typical", "skilled"]:
				var t: Dictionary = sp["styles"][style][mode]
				n_all += int(t["n"])
				f_all += int(t["final"])
				w_all += int(t["won"])
			_row(["%s %s" % [id, mode], n_all, f_all, w_all, _pct(w_all, f_all)])


func _peak_table() -> void:
	print("
### Most creatures on the map at once, over every play
")
	_head(["Level", "In the spread plays", "In the search plays (any tower)"])
	for id: String in LEVELS:
		var sp: Dictionary = _read(id + "_spread.json")
		var se: Dictionary = _read(id + "_search_any.json")
		if sp.is_empty() or se.is_empty():
			continue
		_row([id, sp["peak_max"], se["peak_max"]])


func _det_table() -> void:
	print("\n### Determinism\n")
	_head(["Level", "Plays repeated", "Identical", "Save and load mid-wave", "Identical", "Search repeated identical", "Chain hash"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_det.json")
		if d.is_empty():
			continue
		_row([id, d["plays_checked"], d["plays_identical"], d.get("restores_checked", "-"), d.get("restores_identical", "-"), d["search_repeat_identical"], int(d["chain_hash"])])


func _bench_table() -> void:
	print("\n### Time per tick and peak creatures (microseconds, this PC)\n")
	_head(["Level", "Build", "Won", "Ticks", "Peak creatures", "Mean", "99th pct", "Max", "Ticks with 50+ creatures", "Mean there", "99th pct there"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_bench.json")
		if d.is_empty():
			continue
		for row: Dictionary in d["rows"]:
			var label: String = "best win of the search" if String(row["label"]).ends_with("search_any") else "most crowded play of the spread"
			_row([id, label, "yes" if bool(row["won"]) else "no", row["ticks"], row["peak"], row["mean_us"], row["p99_us"], row["max_us"],
				row["busy_ticks"], row["busy_mean_us"], row["busy_p99_us"]])


## The what-if sweeps of run_whatif.sh (suggestions in the report).
func _whatif_tables() -> void:
	var saved: String = _dir
	_dir = saved.path_join("whatif")
	print("
### What-if: every group's count scaled (Normal). Search = builds found by the seeded search, 800 tries each
")
	_head(["Level", "Count", "Typical random: won", "Typical random: 3 stars", "Any tower: 3-star builds found", "Sling Post only: 3-star builds found", "Catapult only: 3-star builds found", "Best lives left, any tower", "Length of typical wins, min"])
	var game: GameData = GameData.load_from("res://data")
	for id: String in LEVELS:
		for c: int in [150, 200, 250, 300, 400]:
			var base: String = "%s_count%d" % [id, c]
			var sp: Dictionary = _read(base + "_spread.json")
			var any: Dictionary = _read(base + "_any.json")
			if sp.is_empty() and any.is_empty():
				continue
			var cat: Dictionary = _read(base + "_pumpkin_catapult.json")
			var sl: Dictionary = _read(base + "_sling_post.json")
			var t: Dictionary = sp.get("styles", {}).get("typical", {}).get("normal", {"n": 0, "won": 0, "three": 0})
			var best: String = "-"
			if any.has("best_win"):
				best = str(int(any["best_win"]["result"]["lives"]))
			_row([id, "%d%%" % c, _pct(int(t["won"]), int(t["n"])), _pct(int(t["three"]), int(t["n"])),
				_found(any), _found(sl), _found(cat) if not cat.is_empty() else "cannot win (flyers)", best, _minutes(t, game.levels[StringName(id)].waves.size())])
	print("
### What-if, level 1-6: a weaker final wave and more gold (Normal)
")
	_head(["Final wave strength", "Start gold", "Random, all styles: won", "Random: reached the final wave", "Random: won, of those", "Search: wins / tries", "Search: 3-star builds found", "Tries before the first three-star win"])
	for s_value: int in [110, 90, 70, 50]:
		for g: int in [350, 450, 550]:
			var base2: String = "r1_l6_boss%d_gold%d" % [s_value, g]
			var sp2: Dictionary = _read(base2 + "_spread.json")
			var any2: Dictionary = _read(base2 + "_any.json")
			if s_value == 110 and g == 350:
				_dir = saved
				sp2 = _read("r1_l6_spread.json")
				any2 = _read("r1_l6_search_any.json")
				_dir = saved.path_join("whatif")
			if sp2.is_empty():
				continue
			var n: int = 0
			var w: int = 0
			var fin: int = 0
			for style: String in ["casual", "typical", "skilled"]:
				var t2: Dictionary = sp2["styles"][style]["normal"]
				n += int(t2["n"])
				w += int(t2["won"])
				fin += int(t2["final"])
			_row(["%d" % s_value, g, _pct(w, n), _pct(fin, n), _pct(w, fin), "%d / %d" % [int(any2.get("wins", 0)), int(any2.get("evals", 0))],
				int(any2.get("three_star_found", 0)), int(any2.get("first_three_star_eval", -1))])
	_dir = saved


## Mean length in minutes of the wins in a tally: wave time plus 15 s for each build phase.
func _minutes(t: Dictionary, waves: int) -> String:
	if int(t.get("won", 0)) == 0:
		return "-"
	return "%.1f" % ((float(t["ticks_sum"]) / int(t["won"]) / 20.0 + BUILD_SECONDS * waves) / 60.0)


func _found(d: Dictionary) -> String:
	if d.is_empty():
		return "-"
	return "%d of %d" % [int(d["three_star_found"]), int(d["evals"])]


## For each level: the simplest three-star build found with any tower, with the Sling Post
## only and with the Catapult only (fewest purchases, then fewest early calls).
func _builds() -> void:
	print("
### Three-star builds, written out
")
	for id: String in LEVELS:
		for only: String in ["any", "sling_post", "pumpkin_catapult"]:
			var d: Dictionary = _read("%s_search_%s.json" % [id, only])
			if d.is_empty():
				continue
			var best: Dictionary = {}
			var best_key: int = 1000000
			for item: Dictionary in d.get("three_star_best", []):
				var key: int = (item["strategy"]["seq"] as Array).size() * 100 + int(item["result"]["early"]) * 10 + (20 - int(item["result"]["lives"]))
				if key < best_key:
					best_key = key
					best = item
			if best.is_empty():
				print("**%s, %s: no three-star build found.**
" % [id, only])
				continue
			var r: Dictionary = best["result"]
			print("**%s, %s:** %d lives left, %d early calls, %d s of waves at 1x, seed %d, search of %d builds.
" % [
				id, only, int(r["lives"]), int(r["early"]), int(r["ticks"]) / 20, int(d["seed"]), int(d["evals"])])
			print("```
" + String(best["text"]) + "```
")


## Where the losing random plays died: the wave they were lost in, as a share of all plays.
func _died_table() -> void:
	print("
### Where random plays are lost: share of all plays lost in each wave (spread, Normal, all styles)
")
	_head(["Level", "Won", "Wave 1-3", "Wave 4-6", "Wave 7-9", "Wave 10+"])
	for id: String in LEVELS:
		var sp: Dictionary = _read(id + "_spread.json")
		if sp.is_empty():
			continue
		var n: int = 0
		var won: int = 0
		var bands: Array[int] = [0, 0, 0, 0]
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = sp["styles"][style]["normal"]
			n += int(t["n"])
			won += int(t["won"])
			var died: Dictionary = t.get("died_at", {})
			for key: String in died:
				var wave: int = int(key)
				bands[mini(3, (wave - 1) / 3)] += int(died[key])
		_row([id, _pct(won, n), _pct(bands[0], n), _pct(bands[1], n), _pct(bands[2], n), _pct(bands[3], n)])


## The tower number what-ifs of run_stats.sh.
func _stats_table() -> void:
	var saved: String = _dir
	_dir = saved.path_join("stats")
	print("
### What-if on tower numbers (Normal, 800 tries per search, same seeds in every row of a level)
")
	_head(["Level and counts", "Change", "Any tower: 3-star builds", "Sling Post only", "Catapult only", "Typical random: won", "Typical random: 3 stars"])
	var levels: Array = [["r1_l2", "150%"], ["r1_l4", "200%"], ["r1_l5", "150%"]]
	var variants: Array = [["base", "none"], ["splash25", "Catapult splash +0.25 tile"], ["splash50", "Catapult splash +0.5 tile"],
		["damage150", "Catapult damage x1.5"], ["splash50_damage130", "Catapult splash +0.5 tile, damage x1.3"],
		["sling_damage80", "Sling Post damage x0.8"], ["cat_plus_sling_minus", "Catapult splash +0.25, damage x1.25; Sling damage x0.85"]]
	for level: Array in levels:
		for variant: Array in variants:
			var base: String = "%s_%s" % [level[0], variant[0]]
			var any: Dictionary = _read(base + "_any.json")
			if any.is_empty():
				continue
			var sp: Dictionary = _read(base + "_spread.json")
			var t: Dictionary = sp.get("styles", {}).get("typical", {}).get("normal", {"n": 0, "won": 0, "three": 0})
			var cat: Dictionary = _read(base + "_pumpkin_catapult.json")
			_row(["%s at %s" % [level[0], level[1]], variant[1], _found(any), _found(_read(base + "_sling_post.json")),
				_found(cat) if not cat.is_empty() else "cannot win (flyers)", _pct(int(t["won"]), int(t["n"])), _pct(int(t["three"]), int(t["n"]))])
	_dir = saved


## Level 1-6 with one more build spot (run_whatif.sh).
func _spot_table() -> void:
	print("
### What-if, level 1-6: one more build spot (Normal)
")
	_head(["Extra spot (column, row)", "Random, all styles: won", "Random: reached the final wave", "Random: won, of those", "Search: wins / tries", "Search: 3-star builds found", "Tries before the first three-star win"])
	var rows: Array = [["none", "", ""], ["4, 5", "r1_l6_spot4_5_", "w"], ["1, 5", "r1_l6_spot1_5_", "w"], ["2, 8", "r1_l6_spot2_8_", "w"], ["3, 1", "r1_l6_spot3_1_", "w"]]
	var saved: String = _dir
	for row: Array in rows:
		_dir = saved.path_join("whatif") if row[2] == "w" else saved
		var sp: Dictionary = _read(("%sspread.json" % row[1]) if row[2] == "w" else "r1_l6_spread.json")
		var any: Dictionary = _read(("%sany.json" % row[1]) if row[2] == "w" else "r1_l6_search_any.json")
		if sp.is_empty() or any.is_empty():
			continue
		var n: int = 0
		var w: int = 0
		var fin: int = 0
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = sp["styles"][style]["normal"]
			n += int(t["n"])
			w += int(t["won"])
			fin += int(t["final"])
		_row([row[0], _pct(w, n), _pct(fin, n), _pct(w, fin), "%d / %d" % [int(any["wins"]), int(any["evals"])], int(any["three_star_found"]), int(any["first_three_star_eval"])])
	_dir = saved
