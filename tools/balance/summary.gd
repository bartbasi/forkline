# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Turns the JSON files of one run_region1.sh run into the markdown tables used in the report,
## so no number in a report is typed by hand.
##
##   godot --headless --path . --script res://tools/balance/summary.gd -- dir=res://docs/balance/raw/2026-10-23
##
## With pass=1 it prints the tables of a run_pass.sh run instead (plain, solo, search, spread, Twist,
## determinism and benchmark files):
##
##   godot --headless --path . --script res://tools/balance/summary.gd -- dir=res://docs/balance/raw/2026-10-24-b1 pass=1
##
## It prints markdown to the console. It reads only files this tool wrote.

const LEVELS: Array[String] = ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6"]
## The levels of the balance pass (pass=1).
const PASS_LEVELS: Array[String] = ["r1_l1", "r1_l2", "r1_l3", "r1_l4", "r1_l5", "r1_l6", "r2_l1", "r2_l2", "r2_l3", "r2_l4", "r2_l5", "r2_l6"]
const ATTACKERS: Array[String] = ["sling_post", "pumpkin_catapult", "longbow_loft", "firework_tower"]
const BUILD_SECONDS: int = 15

var _dir: String = ""


func _initialize() -> void:
	var whatif: bool = false
	var pass_mode: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("dir="):
			_dir = argument.trim_prefix("dir=")
		if argument == "whatif=1":
			whatif = true
		if argument == "pass=1":
			pass_mode = true
	if pass_mode:
		_pass_tables()
		quit(0)
		return
	if whatif:
		_economy_table()                                    # the old RULES 12.5 guide, kept for the 2026-10-23 report
	_waves_table()
	_recipe_tables()
	_mixed_recipe_table()
	_spread_tables()
	_search_tables()
	_single_tables()
	_exhaust_tables()
	_rerun_whatif_tables()
	_guided_table()
	_coverage_table()
	_mix_tables()
	_length_table()
	_boss_table()
	_peak_table()
	_det_table()
	_bench_table()
	_died_table()
	if whatif:
		_whatif_tables()
		_stats_table()
		_spot_table()
	_builds()
	quit(0)


## Wave sizes from the level files: creatures in each wave, and the biggest.
func _waves_table() -> void:
	print("\n### Wave sizes (creatures in each wave, from the level files)\n")
	_head(["Level", "Waves", "Creatures per wave", "Largest wave", "Creatures in all", "Starting gold"])
	var game: GameData = GameData.load_from("res://data")
	for id: String in LEVELS:
		var level: LevelData = game.levels[StringName(id)]
		var sizes: Array[String] = []
		var biggest: int = 0
		var all: int = 0
		for wave: WaveData in level.waves:
			var count: int = 0
			for group: WaveGroup in wave.groups:
				count += group.count
			sizes.append(str(count))
			biggest = maxi(biggest, count)
			all += count
		_row([id, level.waves.size(), ", ".join(sizes), biggest, all, level.start_gold])


## The mixed recipe of RULES 12.5 (Sling Posts and Catapults in turn, spots with the most road first,
## each upgraded once), and the two one-tower recipes at tier 2, over every gate choice.
func _mixed_recipe_table() -> void:
	print("\n### The three tier 2 recipes over every gate choice: result with the best gate | with the worst gate\n")
	_head(["Level", "Recipe", "Normal", "Relaxed"])
	var wanted: Array[String] = ["sling, catapult, alternating, road order, tier 2", "sling x all, road order, tier 2", "catapult x all, tier 2",
		"sling, catapult, alternating, road order, no upgrades"]
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_recipes.json")
		if d.is_empty():
			continue
		for r: Dictionary in d["recipes"]:
			if not wanted.has(String(r["recipe"])):
				continue
			var cells: Array = [id, r["recipe"]]
			for mode: String in ["normal", "relaxed"]:
				var s: Dictionary = r["summary"][mode]
				cells.append("%s \\| %s (wins on %d of %d gate choices)" % [_outcome(s["best"], mode == "relaxed"), _outcome(s["worst"], mode == "relaxed"),
					int(s["wins"]), int(s["gates_tried"])])
			_row(cells)


## What the three-star builds of the any-tower search hold: tower mix, lives left, tower count, early calls.
func _mix_tables() -> void:
	print("\n### Three-star builds found (any-tower search): tower mix at the end, as builds (top 6 mixes)\n")
	_head(["Level", "Three-star builds", "Mean Sling Posts", "Mean Catapults", "Mixes (towers at the end: builds)", "Lives left (lives: builds)", "Towers built (count: builds)", "Builds that called early"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
		if d.is_empty():
			continue
		_row([id, d["three_star_found"], _mean_of(d["three_star_mix"], "sling_post"), _mean_of(d["three_star_mix"], "pumpkin_catapult"), _top(d["three_star_mix"], 6, false), _top(d["three_star_lives"], 5, true),
			_top(d["three_star_towers"], 8, true), d["three_star_early_used"]])


## "key: n" pairs, biggest first (or by numeric key, biggest first, when by_key is true).
func _top(hist: Dictionary, limit: int, by_key: bool) -> String:
	var keys: Array = hist.keys()
	if by_key:
		keys.sort_custom(func(a: String, b: String) -> bool: return int(a) > int(b))
	else:
		keys.sort_custom(func(a: String, b: String) -> bool: return int(hist[a]) > int(hist[b]))
	var parts: Array[String] = []
	for key: String in keys.slice(0, limit):
		parts.append("%s: %d" % [key, int(hist[key])])
	return "; ".join(parts)


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
	_head(["Level", "Style", "Plays", "Won", "Keep 15 lives (2 stars)", "Three stars", "Star 3 rule met, share of wins", "Mean lives left in a win"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var all: Dictionary = {"n": 0, "won": 0, "two": 0, "three": 0, "rule3": 0, "lives_sum": 0}
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = d["styles"][style]["normal"]
			_row([id, style, int(t["n"]), _pct(int(t["won"]), int(t["n"])), _pct(int(t["two"]), int(t["n"])),
				_pct(int(t["three"]), int(t["n"])), _pct(int(t.get("rule3", 0)), int(t["won"])), "-" if int(t["won"]) == 0 else "%.1f" % (float(t["lives_sum"]) / int(t["won"]))])
			for key: String in all:
				all[key] = int(all[key]) + int(t.get(key, 0))
		_row([id, "**all**", all["n"], _pct(int(all["won"]), int(all["n"])), _pct(int(all["two"]), int(all["n"])),
			_pct(int(all["three"]), int(all["n"])), _pct(int(all["rule3"]), int(all["won"])), "-" if int(all["won"]) == 0 else "%.1f" % (float(all["lives_sum"]) / int(all["won"]))])
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
	_head(["Level", "Builds tried", "Wins", "Wins that met the star 3 rule", "Three-star wins", "Tried before the first three-star win", "Best lives left"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
		if d.is_empty():
			continue
		var best: int = 0
		if d.has("best_win"):
			best = int(d["best_win"]["result"]["lives"])
		_row([id, d["evals"], d["wins"], d.get("rule3_wins", "-"), d["three_star_found"], d["first_three_star_eval"], best])


func _single_tables() -> void:
	print("\n### One tower type alone (search, Normal)\n")
	_head(["Level", "Only", "Seed", "Builds tried", "Wins", "Wins that met the star 3 rule", "Most lives left in such a win", "Three-star wins", "Best result found"])
	for id: String in LEVELS:
		for only: String in ["sling_post", "pumpkin_catapult"]:
			for suffix: String in ["", "_b"]:
				_single_row(id, only, suffix)


func _single_row(id: String, only: String, suffix: String) -> void:
	var d: Dictionary = _read("%s_search_%s%s.json" % [id, only, suffix])
	if d.is_empty():
		return
	var best: String = "no win"
	if d.has("top"):
		var r: Dictionary = d["top"]["result"]
		if bool(r["won"]):
			var stars: int = int(r["stars"])
			best = "won, %d lives left, %s" % [int(r["lives"]), "3 stars" if stars == 7 else ("2 stars" if (stars & 2) != 0 else "1 star")]
		else:
			best = "lost after %d of %d waves cleared" % [int(r["cleared"]), 0 if not r.has("waves") else int(r["waves"])]
	_row([id, only, int(d["seed"]), d["evals"], d["wins"], d.get("rule3_wins", "-"), d.get("rule3_best_lives", "-"), d["three_star_found"], best])


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


## The extra jobs of run_exhaust.sh: the exhaustive 1-3 check and the longer one-tower searches.
func _exhaust_tables() -> void:
	var saved: String = _dir
	_dir = saved.path_join("exhaust")
	print("\n### Level 1-3, one tower type, every build of one or two towers (exhaustive, Normal)\n")
	_head(["Only", "Builds in the set", "Builds played", "Wins", "Wins that met the star 3 rule (at most 2 towers)", "Most lives left in such a win", "Three-star wins"])
	for only: String in ["sling_post", "pumpkin_catapult"]:
		var played: int = 0
		var total: int = 0
		var wins: int = 0
		var rule3: int = 0
		var best: int = -1
		var threes: int = 0
		var shards: int = 0
		for shard: int in 10:
			var d: Dictionary = _read("r1_l3_%s_s%d.json" % [only, shard])
			if d.is_empty():
				continue
			shards += 1
			total = int(d["builds_in_all"])
			played += int(d["evals"])
			wins += int(d["wins"])
			rule3 += int(d["rule3_wins"])
			best = maxi(best, int(d["rule3_best_lives"]))
			threes += int(d["three_star_found"])
		if shards > 0:
			_row([only, "%d (%d of 10 shards)" % [total, shards], played, wins, rule3, best, threes])
	print("\n### Longer searches with one tower type (8000 builds, Normal)\n")
	_head(["Level", "Only", "Seed", "Builds tried", "Wins", "Wins that met the star 3 rule", "Most lives left in such a win", "Three-star wins"])
	for id: String in LEVELS:
		for only: String in ["sling_post", "pumpkin_catapult"]:
			var d2: Dictionary = _read("%s_long_%s.json" % [id, only])
			if d2.is_empty():
				continue
			_row([id, only, int(d2["seed"]), d2["evals"], d2["wins"], d2["rule3_wins"], d2["rule3_best_lives"], d2["three_star_found"]])
	_dir = saved


## The small what-ifs of the 2026-10-24 rerun (files in whatif/).
func _rerun_whatif_tables() -> void:
	var saved: String = _dir
	_dir = saved.path_join("whatif")
	print("\n### What-if, level 1-5: other star 3 rules (any-tower search, 3000 builds, Normal)\n")
	_head(["Star 3 rule", "Seed", "Wins", "Wins that met the rule", "Three-star wins", "Tried before the first three-star win", "Towers in the three-star builds (count: builds)"])
	for n: int in [4, 3]:
		var d: Dictionary = _read("r1_l5_towers%d_any.json" % n)
		if not d.is_empty():
			_row(["At most %d towers" % n, int(d["seed"]), d["wins"], d["rule3_wins"], d["three_star_found"], d["first_three_star_eval"], _top(d["three_star_towers"], 5, true)])
	print("\n### What-if, level 1-3: tier 1 only (the Twist \"No Upgrades\"), every build of up to 4 towers of either kind, default aim\n")
	_head(["Builds in the set", "Builds played", "Wins"])
	var all: int = 0
	var played: int = 0
	var wins: int = 0
	for shard: int in 4:
		var s: Dictionary = _read("r1_l3_tier1_only_s%d.json" % shard)
		if s.is_empty():
			continue
		all = int(s["builds_in_all"])
		played += int(s["evals"])
		wins += int(s["wins"])
	_row([all, played, wins])
	_dir = saved


## Mean number of one tower id per build, from a mix histogram ("sling_post:3,pumpkin_catapult:2": builds).
func _mean_of(mix: Dictionary, id: String) -> String:
	var total: int = 0
	var builds: int = 0
	for key: String in mix:
		builds += int(mix[key])
		for part: String in key.split(","):
			if part.begins_with(id + ":"):
				total += int(part.get_slice(":", 1)) * int(mix[key])
	return "-" if builds == 0 else "%.1f" % (float(total) / builds)


## The guided style (run.gd style=guided): every spot, both kinds, all tier 2, random places and gate.
func _guided_table() -> void:
	var saved: String = _dir
	_dir = saved.path_join("guided")
	print("\n### Guided random plays (every spot, both kinds, all tier 2, random places and gate)\n")
	_head(["Level", "Plays", "Normal: won", "Normal: keep 15 lives", "Normal: mean lives left in a win", "Relaxed: won"])
	for id: String in LEVELS:
		var d: Dictionary = _read(id + "_guided.json")
		if d.is_empty():
			continue
		var t: Dictionary = d["styles"]["guided"]["normal"]
		var r: Dictionary = d["styles"]["guided"]["relaxed"]
		_row([id, int(t["n"]), _pct(int(t["won"]), int(t["n"])), _pct(int(t["two"]), int(t["n"])),
			"-" if int(t["won"]) == 0 else "%.1f" % (float(t["lives_sum"]) / int(t["won"])), _pct(int(r["won"]), int(r["n"]))])
	_dir = saved



# The tables of a balance pass (run_pass.sh, RULES 12.6).

func _pass_tables() -> void:
	_pass_waves()
	_pass_plain_normal()
	_pass_plain_relaxed()
	_pass_three_stars()
	_pass_solo()
	_pass_random()
	_pass_length()
	_pass_size()
	_pass_twists()
	_pass_whatif()
	_pass_coverage()
	_pass_det()
	_pass_builds()


func _stars_of(bits: int) -> int:
	return 1 + (1 if (bits & 2) != 0 else 0) + (1 if (bits & 4) != 0 else 0)


## "won, 17 lives, 2 stars" or "lost in wave 5 of 11".
func _cell_of(res: Dictionary, waves: int) -> String:
	if res.is_empty():
		return "-"
	if bool(res["won"]):
		var stars: int = _stars_of(int(res["stars"]))
		return "won, %d lives, %d star%s" % [int(res["lives"]), stars, "" if stars == 1 else "s"]
	return "lost in wave %d of %d" % [int(res["cleared"]) + 1, waves]


## The ids of a level: region number and level number.
func _num(id: String) -> int:
	return int(id.get_slice("_l", 1))


func _region(id: String) -> int:
	return int(id.get_slice("_", 0).trim_prefix("r"))


func _label(id: String) -> String:
	return "%d-%d" % [_region(id), _num(id)]


func _pass_waves() -> void:
	print("\n### Wave sizes (creatures in each wave, a Puffball counts as itself and its 3 Puffs)\n")
	_head(["Level", "Waves", "Creatures per wave", "Largest wave"])
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_plain.json")
		if d.is_empty():
			continue
		var sizes: Array[String] = []
		for size: Variant in d["wave_sizes"]:
			sizes.append(str(int(size)))
		_row([_label(id), d["waves"], ", ".join(sizes), int(d["largest_wave"])])


func _pass_plain_normal() -> void:
	print("\n### Plain mixed recipe on Normal (best placement = most lives, stars break ties; none = no gates)\n")
	_head(["Level", "Placements tried", "Wins", "Best placement", "Best result", "No gates", "Worst placement", "Worst result", "Bar", "Bar met"])
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_plain.json")
		if d.is_empty():
			continue
		var n: Dictionary = d["summary"]["normal"]
		var waves: int = int(d["waves"])
		var best: Dictionary = n["best"]
		var need: bool = (_num(id) <= 5) if _region(id) == 1 else (_num(id) <= 2)
		var bar: String = "15 lives or more" if need else "win"
		var met: bool = bool(best["won"]) and (int(best["lives"]) >= 15 or not need)
		_row([_label(id), n["placements"], n["wins"], best["gate"], _cell_of(best, waves), _cell_of(n["none"], waves),
			n["worst"]["gate"], _cell_of(n["worst"], waves), bar, "yes" if met else "**NO**"])


func _pass_plain_relaxed() -> void:
	print("\n### Plain mixed recipe on Relaxed (bar: wins with no gates and with the best placement)\n")
	_head(["Level", "Placements tried", "Wins", "No gates", "Best placement", "Best result", "Worst result", "Bar met"])
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_plain.json")
		if d.is_empty():
			continue
		var r: Dictionary = d["summary"]["relaxed"]
		var waves: int = int(d["waves"])
		var met: bool = bool(r["none"]["won"]) and bool(r["best"]["won"])
		_row([_label(id), r["placements"], r["wins"], _cell_of(r["none"], waves), r["best"]["gate"], _cell_of(r["best"], waves),
			_cell_of(r["worst"], waves), "yes" if met else "**NO**"])


func _pass_three_stars() -> void:
	print("\n### All three stars: search with every tower the level offers (Normal)\n")
	_head(["Level", "Seed", "Builds tried", "Wins", "Wins that met the star 3 rule", "Three-star wins", "Tried before the first three-star win", "Most lives left in a three-star win", "Found"])
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
		if d.is_empty():
			continue
		var best: int = -1
		for key: String in d["three_star_lives"]:
			best = maxi(best, int(key))
		_row([_label(id), int(d["seed"]), d["evals"], d["wins"], d["rule3_wins"], d["three_star_found"], d["first_three_star_eval"], "-" if best < 0 else best,
			"yes" if int(d["three_star_found"]) > 0 else "**NO**"])


func _pass_solo() -> void:
	print("\n### No super tower: one attacking tower plus the level's Bells and Bakeries, two seeds (Normal)\n")
	print("Outcomes are the number of builds that lost, won with 1 star, with 2 stars, with 3 stars. Best is the best result the search found.\n")
	_head(["Level", "Attacker", "Seed", "Builds tried", "Outcomes (lost / 1 / 2 / 3 stars)", "Wins that met the star 3 rule", "Most lives left in such a win (15 needed)", "Three-star wins", "Best result found"])
	for id: String in PASS_LEVELS:
		for only: String in ATTACKERS:
			for suffix: String in ["a", "b"]:
				var d: Dictionary = _read("%s_solo_%s_%s.json" % [id, only, suffix])
				if d.is_empty():
					continue
				var o: Dictionary = d["outcomes"]
				var best: String = "no win"
				if d.has("top"):
					best = _cell_of(d["top"]["result"], int(d["top"]["result"]["waves"]))
				_row([_label(id), only, int(d["seed"]), d["evals"], "%d / %d / %d / %d" % [int(o["lost"]), int(o["1"]), int(o["2"]), int(o["3"])],
					d["rule3_wins"], "-" if int(d["rule3_best_lives"]) < 0 else d["rule3_best_lives"], d["three_star_found"], best])
	print("\nVerdict per level (no three-star win in any search is a pass):\n")
	_head(["Level", "Attackers searched", "Searches", "Three-star wins found", "Verdict"])
	for id: String in PASS_LEVELS:
		var attackers: int = 0
		var threes: int = 0
		var runs: int = 0
		for only: String in ATTACKERS:
			var seen: bool = false
			for suffix: String in ["a", "b"]:
				var d: Dictionary = _read("%s_solo_%s_%s.json" % [id, only, suffix])
				if d.is_empty():
					continue
				seen = true
				runs += 1
				threes += int(d["three_star_found"])
			if seen:
				attackers += 1
		for extra: Dictionary in _extra_results("extra"):
			if String(extra["level"]) == id:
				runs += 1
				threes += int(extra["three_star_found"])
		if runs > 0:
			_row([_label(id), attackers, runs, threes, "pass" if threes == 0 else "**FAIL**"])
	_pass_extra()


func _pass_random() -> void:
	print("\n### Random play (250 per style, 750 plays per difficulty). Bar: three stars in under 10%\n")
	_head(["Level", "Seed", "Normal: won", "Normal: keep 15 lives", "Normal: three stars", "Casual / typical / skilled three stars", "Relaxed: won", "Bar met"])
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_spread.json")
		if d.is_empty():
			continue
		var all: Dictionary = {"n": 0, "won": 0, "two": 0, "three": 0}
		var relaxed_n: int = 0
		var relaxed_won: int = 0
		var by_style: Array[String] = []
		for style: String in ["casual", "typical", "skilled"]:
			var t: Dictionary = d["styles"][style]["normal"]
			for key: String in all:
				all[key] = int(all[key]) + int(t[key])
			by_style.append(_pct(int(t["three"]), int(t["n"])))
			relaxed_n += int(d["styles"][style]["relaxed"]["n"])
			relaxed_won += int(d["styles"][style]["relaxed"]["won"])
		var rate: float = 100.0 * int(all["three"]) / maxi(int(all["n"]), 1)
		_row([_label(id), int(d["seed"]), _pct(int(all["won"]), int(all["n"])), _pct(int(all["two"]), int(all["n"])),
			"%d of %d (%.1f%%)" % [int(all["three"]), int(all["n"]), rate], " / ".join(by_style), _pct(relaxed_won, relaxed_n), "yes" if rate < 10.0 else "**NO**"])


func _pass_length() -> void:
	print("\n### Length at 1x with no early calls: wave time plus 15 s for each build phase (bar: 5 to 10 minutes)\n")
	print("Plain: its best placement on Normal (a loss ends early, so only a win gives a length). Search build: the best win of the any-tower search, played again with early calls off.\n")
	_head(["Level", "Waves", "Plain: wave time", "Plain: total", "Search build, early calls off", "Wave time", "Total", "Plain in 5 to 10 min"])
	for id: String in PASS_LEVELS:
		var p: Dictionary = _read(id + "_plain.json")
		var b: Dictionary = _read(id + "_bench.json")
		if p.is_empty():
			continue
		var waves: int = int(p["waves"])
		var cells: Array = [_label(id), waves]
		var plain_total: float = -1.0
		var best: Dictionary = p["summary"]["normal"]["best"]
		if bool(best["won"]):
			var secs: float = float(best["ticks"]) / 20.0
			plain_total = (secs + BUILD_SECONDS * waves) / 60.0
			cells.append("%d s" % int(secs))
			cells.append("%.1f min" % plain_total)
		else:
			cells.append_array(["-", "-"])
		if b.is_empty() or (b["rows"] as Array).is_empty():
			cells.append_array(["-", "-", "-"])
		else:
			var row: Dictionary = b["rows"][0]
			cells.append(_cell_of({"won": row["calm_won"], "stars": row["calm_stars"], "lives": row["calm_lives"], "cleared": row["calm_waves"]}, waves))
			var secs2: float = float(row["calm_ticks"]) / 20.0
			cells.append("%d s" % int(secs2))
			cells.append("%.1f min" % ((secs2 + BUILD_SECONDS * waves) / 60.0))
		cells.append("yes" if plain_total >= 5.0 and plain_total <= 10.0 else "**NO**")
		_row(cells)


func _pass_size() -> void:
	print("\n### Size and speed: largest wave, most creatures on the map at once, microseconds per tick (this PC, headless)\n")
	_head(["Level", "Largest wave", "Peak: plain best play", "Peak: random plays", "Peak: search plays", "Benchmark build", "Peak", "Mean", "99th pct", "Max", "Mean with 50+ creatures", "99th pct with 50+"])
	for id: String in PASS_LEVELS:
		var p: Dictionary = _read(id + "_plain.json")
		var sp: Dictionary = _read(id + "_spread.json")
		var se: Dictionary = _read(id + "_search_any.json")
		var b: Dictionary = _read(id + "_bench.json")
		if p.is_empty():
			continue
		var plain_peak: int = int(p["summary"]["normal"]["best"]["peak"])
		var rows: Array = b.get("rows", [{}])
		for row: Variant in rows:
			var r: Dictionary = row
			var label: String = "-"
			if not r.is_empty():
				label = "search best win" if String(r["label"]).ends_with("search_any") else "most crowded random play"
			_row([_label(id), int(p["largest_wave"]), plain_peak, sp.get("peak_max", "-"), se.get("peak_max", "-"), label, r.get("peak", "-"), r.get("mean_us", "-"),
				r.get("p99_us", "-"), r.get("max_us", "-"), "-" if int(r.get("busy_ticks", 0)) == 0 else r["busy_mean_us"], "-" if int(r.get("busy_ticks", 0)) == 0 else r["busy_p99_us"]])


func _pass_twists() -> void:
	print("\n### Twists: some strategy wins on Normal\n")
	print("Plain: the plain recipe with the Twist, over every placement the Twist leaves. Search: 1500 builds with every tower the Twist leaves.\n")
	_head(["Level", "Twist", "Plain: placements", "Plain: wins", "Plain: best result", "Plain: no gates", "Search seed", "Search: builds", "Search: wins", "Search: best win", "Normal win found"])
	var game: GameData = GameData.load_from("res://data")
	for id: String in PASS_LEVELS:
		var p: Dictionary = _read(id + "_plain_twist.json")
		var s: Dictionary = _read(id + "_search_twist.json")
		if p.is_empty() and s.is_empty():
			continue
		var level: LevelData = game.levels[StringName(id)]
		var n: Dictionary = p.get("summary", {}).get("normal", {})
		var waves: int = int(p.get("waves", level.waves.size()))
		var won_plain: bool = not n.is_empty() and int(n["wins"]) > 0
		var won_search: bool = not s.is_empty() and int(s["wins"]) > 0
		var best_text: String = "-"
		if s.has("best_win"):
			best_text = _cell_of(s["best_win"]["result"], waves)
		elif s.has("top"):
			best_text = _cell_of(s["top"]["result"], waves)
		_row([_label(id), level.twist_name, n.get("placements", "-"), n.get("wins", "-"), _cell_of(n.get("best", {}), waves), _cell_of(n.get("none", {}), waves),
			int(s.get("seed", 0)), s.get("evals", "-"), s.get("wins", "-"), best_text, "yes" if won_plain or won_search else "**NO**"])


func _pass_coverage() -> void:
	print("\n### Towers and paths in the three-star wins found (any-tower search, Normal): builds using each\n")
	var keys: Array[String] = ["sling_post", "quickshot", "stone_sling", "pumpkin_catapult", "prize_pumpkin", "jam_pot", "longbow_loft", "giant_bow", "triple_bow",
		"lullaby_bell", "hush_bell", "night_bell"]
	var head: Array = ["Level", "Three-star wins"]
	head.append_array(keys)
	_head(head)
	var totals: Dictionary = {}
	var total_wins: int = 0
	for id: String in PASS_LEVELS:
		var use: Dictionary = {}
		var wins: int = 0
		var files: Array[String] = [id + "_search_any.json"]
		for file_name: String in files:
			var d: Dictionary = _read(file_name)
			if d.is_empty():
				continue
			wins += int(d["three_star_found"])
			var u: Dictionary = d["three_star_builds_using"]
			for key: String in u:
				use[key] = int(use.get(key, 0)) + int(u[key])
		var cells: Array = [_label(id), wins]
		for key: String in keys:
			cells.append(int(use.get(key, 0)))
			totals[key] = int(totals.get(key, 0)) + int(use.get(key, 0))
		total_wins += wins
		_row(cells)
	var last: Array = ["**all**", total_wins]
	for key: String in keys:
		last.append(int(totals.get(key, 0)))
	_row(last)
	print("\nTower types that no level in this table offers yet: Firework Tower and Bakery (regions 3 and 4).\n")


func _pass_det() -> void:
	print("\n### Determinism: same inputs, same result\n")
	print("Each job plays 24 strategies twice and once from saved strategy data, replays them with a save and load mid-wave at 3 points, and repeats a 60 build search. The last column is the same job run again in a new process.\n")
	_head(["Level", "Seed", "Plays repeated", "Identical", "Save and load mid-wave", "Identical", "Search repeated identical", "Chain hash", "New process: same chain hash"])
	for id: String in PASS_LEVELS:
		for variant: String in ["det", "det_twist"]:
			var d: Dictionary = _read("%s_%s.json" % [id, variant])
			if d.is_empty():
				continue
			var again: Dictionary = _read("%s_det_again.json" % id) if variant == "det" else {}
			var same: String = "-"
			if variant == "det" and not again.is_empty():
				same = "yes" if int(again["chain_hash"]) == int(d["chain_hash"]) else "**NO**"
			_row([_label(id) + (" Twist" if variant == "det_twist" else ""), int(d["seed"]), d["plays_checked"], d["plays_identical"], d["restores_checked"], d["restores_identical"],
				d["search_repeat_identical"], int(d["chain_hash"]), same])


## The plain recipe of each level written out, and the simplest three-star build the any-tower search found.
func _pass_builds() -> void:
	print("\n### Plain recipe, written out\n")
	for id: String in PASS_LEVELS:
		var p: Dictionary = _read(id + "_plain.json")
		if p.is_empty():
			continue
		print("**%s**, as played at its best placement (%s):\n" % [_label(id), p["summary"]["normal"]["best"]["gate"]])
		print("```\n" + String(p["recipe_text"]) + "```\n")
	print("\n### Three-star builds, written out (simplest found by the any-tower search)\n")
	for id: String in PASS_LEVELS:
		var d: Dictionary = _read(id + "_search_any.json")
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
			print("**%s: no three-star build found.**\n" % _label(id))
			continue
		var r: Dictionary = best["result"]
		print("**%s:** %d lives left, %d early calls, seed %d, search of %d builds.\n" % [_label(id), int(r["lives"]), int(r["early"]), int(d["seed"]), int(d["evals"])])
		print("```\n" + String(best["text"]) + "```\n")


## The star 3 what-ifs of run_whatif_b1.sh (files in whatif/).
func _pass_whatif() -> void:
	var saved: String = _dir
	_dir = saved.path_join("whatif")
	if not FileAccess.file_exists(_dir.path_join("jobs.txt")):
		_dir = saved
		return
	var rules: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(_dir.path_join("jobs.txt")).split("
", false):
		var level: String = ""
		var tweak: String = ""
		var out: String = ""
		for word: String in line.split(" ", false):
			if word.begins_with("level="):
				level = word.trim_prefix("level=")
			if word.begins_with("tweak=star3:"):
				tweak = word.trim_prefix("tweak=star3:")
			if word.begins_with("out="):
				out = word.get_file().get_basename()
		if tweak != "" and not out.begins_with("check_"):
			rules[out.get_slice("_solo_", 0).get_slice("_any", 0)] = [level, tweak]
	print("
### What-if: other star 3 rules on the levels where one attacker earned three stars (Normal, one seed per search)
")
	print("A rule works when the any-tower search still finds three-star wins and no one-attacker search does. A pass here rests on one 2500 build search per tower; the table of longer checks below can overrule it.
")
	_head(["Level", "Star 3 rule tried", "Search", "Seed", "Builds tried", "Wins", "Wins that met the rule", "Most lives left in such a win", "Three-star wins", "Verdict"])
	var keys: Array = rules.keys()
	keys.sort()
	for key: String in keys:
		var level2: String = rules[key][0]
		var tweak2: String = rules[key][1]
		var any: Dictionary = _read(key + "_any.json")
		var any_threes: int = int(any.get("three_star_found", -1))
		var solo_threes: int = 0
		var solos_seen: int = 0
		var rows: Array = []
		if not any.is_empty():
			rows.append(["any tower", any])
		for only: String in ATTACKERS:
			var d: Dictionary = _read("%s_solo_%s.json" % [key, only])
			if d.is_empty():
				continue
			solos_seen += 1
			solo_threes += int(d["three_star_found"])
			rows.append([only + " + support", d])
		var verdict: String = "pass" if any_threes > 0 and solo_threes == 0 else ("**FAIL: a single attacker wins**" if solo_threes > 0 else "**FAIL: no three-star win at all**")
		for i: int in rows.size():
			var d2: Dictionary = rows[i][1]
			_row([_label(level2), tweak2.replace(";", " "), rows[i][0], int(d2["seed"]), d2["evals"], d2["wins"], d2["rule3_wins"],
				"-" if int(d2["rule3_best_lives"]) < 0 else d2["rule3_best_lives"], d2["three_star_found"], verdict if i == 0 else ""])
	# Level 2-3 with Flitters added (a level file, not a rule): its own rule, No tower above tier 2.
	var variants: Array = [["r2_l3_flitters", "4, 5 and 6"], ["r2_l3_flitters_b", "2, 3 and 4"]]
	for variant: Array in variants:
		var flit_any: Dictionary = _read(variant[0] + "_any.json")
		if flit_any.is_empty():
			continue
		print("
### What-if: level 2-3 with Flitters added to waves 4, 6 and 8 (%s of them), star 3 rule unchanged (No tower above tier 2)
" % variant[1])
		_head(["Search", "Seed", "Builds tried", "Wins", "Wins that met the rule", "Most lives left in such a win", "Three-star wins", "Verdict"])
		var flit_rows: Array = [["any tower", flit_any]]
		var flit_threes: int = 0
		for only2: String in ATTACKERS:
			var d3: Dictionary = _read("%s_solo_%s.json" % [variant[0], only2])
			if not d3.is_empty():
				flit_rows.append([only2 + " + support", d3])
				flit_threes += int(d3["three_star_found"])
		var flit_verdict: String = "pass" if int(flit_any["three_star_found"]) > 0 and flit_threes == 0 else "**FAIL**"
		for j: int in flit_rows.size():
			var d4: Dictionary = flit_rows[j][1]
			_row([flit_rows[j][0], int(d4["seed"]), d4["evals"], d4["wins"], d4["rule3_wins"], "-" if int(d4["rule3_best_lives"]) < 0 else d4["rule3_best_lives"],
				d4["three_star_found"], flit_verdict if j == 0 else ""])
	var checks: Array = _extra_results(".", "check_")
	if not checks.is_empty():
		print("
### Longer checks of the recommended changes (6000 builds for a lone attacker, 2500 for an any-tower search; Normal)
")
		print("The file name says the level, the change (tier2 = No tower above tier 2, towers4 = at most 4 towers, nobell = Build no Lullaby Bells, flitters_b = 2-3 with 2, 3 and 4 Flitters) and the tower.
")
		_head(["Check", "Seed", "Builds tried", "Wins", "Wins that met the rule", "Most lives left in such a win (15 needed)", "Three-star wins"])
		for d2: Dictionary in checks:
			_row([String(d2["file"]).trim_prefix("check_").trim_suffix(".json"), int(d2["seed"]), d2["evals"], d2["wins"], d2["rule3_wins"],
				"-" if int(d2["rule3_best_lives"]) < 0 else d2["rule3_best_lives"], d2["three_star_found"]])
	_dir = saved


## Every result file in a sub folder of the raw folder (sorted by name), for the longer searches of the report.
func _extra_results(sub: String, prefix: String = "") -> Array:
	var out: Array = []
	var names: PackedStringArray = DirAccess.get_files_at(_dir.path_join(sub))
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".json") and file_name != "jobs.json" and file_name.begins_with(prefix):
			var d: Dictionary = _read(sub + "/" + file_name)
			if d.has("level") and d.has("evals"):
				d["file"] = file_name
				out.append(d)
	return out


## Longer lone-attacker searches (extra/): a 2500 build search can miss (2-2).
func _pass_extra() -> void:
	var rows: Array = _extra_results("extra")
	if rows.is_empty():
		return
	print("
Longer lone-attacker searches (6000 builds), added after the pass because a 2500 build search can miss:
")
	_head(["Level", "Attacker", "Seed", "Builds tried", "Outcomes (lost / 1 / 2 / 3 stars)", "Wins that met the star 3 rule", "Most lives left in such a win (15 needed)", "Three-star wins"])
	for d: Dictionary in rows:
		var o: Dictionary = d["outcomes"]
		_row([_label(String(d["level"])), String(d["only"]).trim_prefix("solo:"), int(d["seed"]), d["evals"], "%d / %d / %d / %d" % [int(o["lost"]), int(o["1"]), int(o["2"]), int(o["3"])],
			d["rule3_wins"], "-" if int(d["rule3_best_lives"]) < 0 else d["rule3_best_lives"], d["three_star_found"]])
