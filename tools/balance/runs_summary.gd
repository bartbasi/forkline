# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Turns the JSON files of one run_runs.sh run into the markdown tables of the run and daily report,
## so no number in the report is typed by hand.
##
##   godot --headless --path . --script res://tools/balance/runs_summary.gd -- dir=C:/path/docs/balance/raw/2026-10-24-b2
##   ... part=det|rates|search|length|waves|boss|maps|towers|cards|daily|risk|whatif   (default: all)
##
## It prints markdown to the console. It reads only files runs.gd wrote.

const BUILD_SECONDS: int = 15
const CONFIGS: Array[String] = ["base_r0", "base_r1", "all_r0", "all_r1"]
const CONFIG_NAMES: Dictionary = {"base_r0": "Normal, no unlocks", "base_r1": "Relaxed, no unlocks", "all_r0": "Normal, all cards", "all_r1": "Relaxed, all cards"}

var _dir: String = ""
var _game: GameData = null
var _rates: Dictionary = {}                       # config to its rows
var _cards: Array = []


func _initialize() -> void:
	var part: String = "all"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("dir="):
			_dir = argument.trim_prefix("dir=")
		if argument.begins_with("part="):
			part = argument.trim_prefix("part=")
	_game = GameData.load_from("res://data")
	for config: String in CONFIGS:
		_rates[config] = _load_rows("rates_%s_" % config)
	if _rates["base_r0"].size() > 0:
		_cards = _first_file("rates_base_r0_").get("cards", [])
	var parts: Dictionary = {"det": _det, "rates": _rates_tables, "search": _search_tables, "length": _length_tables,
		"waves": _wave_tables, "boss": _boss_tables, "maps": _map_tables, "towers": _tower_tables, "cards": _card_tables,
		"daily": _daily_tables, "risk": _risk_tables, "cardvalue": _cardvalue_tables, "whatif": _whatif_tables, "ironshell": _ironshell_tables, "lives": _lives_tables}
	for part_name: String in parts.keys():
		if part == "all" or part == part_name:
			(parts[part_name] as Callable).call()
	quit(0)


# Reading.

func _files(prefix: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(_dir)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.begins_with(prefix) and file.ends_with(".json"):
			out.append(file)
	out.sort()
	return out


func _read(file: String) -> Dictionary:
	if not FileAccess.file_exists(_dir.path_join(file)):
		return {}
	var text: String = FileAccess.get_file_as_string(_dir.path_join(file))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _first_file(prefix: String) -> Dictionary:
	var files: Array[String] = _files(prefix)
	if files.is_empty():
		return {}
	return _read(files[0])


func _load_rows(prefix: String) -> Array:
	var rows: Array = []
	for file: String in _files(prefix):
		rows.append_array(_read(file).get("rows", []))
	return rows


# Small helpers.

func _head(columns: Array) -> void:
	print("| " + " | ".join(PackedStringArray(columns.map(func(c: Variant) -> String: return str(c)))) + " |")
	print("|" + "---|".repeat(columns.size()))


func _row(cells: Array) -> void:
	print("| " + " | ".join(PackedStringArray(cells.map(func(c: Variant) -> String: return str(c)))) + " |")


func _pct(part: int, whole: int) -> String:
	if whole <= 0:
		return "-"
	return "%.1f%%" % (100.0 * part / whole)


func _rate(part: int, whole: int) -> String:
	if whole <= 0:
		return "-"
	return "%s (%d/%d)" % [_pct(part, whole), part, whole]


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: Variant in values:
		total += float(v)
	return total / values.size()


## Percentile q (0 to 1) of numbers, by nearest rank.
func _quant(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)])


func _minutes(row: Dictionary) -> float:
	return (float(row["ticks"]) / 20.0 + BUILD_SECONDS * int(row["builds"])) / 60.0


func _wave_minutes(row: Dictionary) -> float:
	return float(row["ticks"]) / 20.0 / 60.0


func _won(rows: Array) -> int:
	var n: int = 0
	for r: Dictionary in rows:
		if bool(r["won"]):
			n += 1
	return n


## Rows filtered by a callable on the row.
func _where(rows: Array, test: Callable) -> Array:
	return rows.filter(test)


func _plan(run_seed: int) -> Dictionary:
	return MapAssembler.plan(run_seed, _game.run)


# Determinism.

func _det() -> void:
	print("\n### Same seed, same run\n")
	var first: Dictionary = _read("det.json")
	var again: Dictionary = _read("det_again.json")
	if first.is_empty():
		print("(no det.json)")
		return
	var rows: Array = first["rows"]
	var dailies: Array = first["daily_rows"]
	_head(["Check", "Runs (seeds 1 to 50)", "Dailies (first 50 days)"])
	for item: Array in [
		["Same seed gives the same map and waves, built twice", "map_equal", ""],
		["Same seed and picks, played twice: equal result, battle state and run state", "again_equal", "again_equal"],
		["Save and load in the middle of a wave: equal to the play with no save", "wave_restore_equal", "wave_restore_equal"],
		["Save and load with a draft open: same offers, equal to the play with no save", "draft_restore_equal", "draft_restore_equal"]]:
		var key_a: String = item[1]
		var key_b: String = item[2]
		var good_a: int = 0
		for r: Dictionary in rows:
			if bool(r.get(key_a, false)):
				good_a += 1
		var good_b: int = 0
		for r: Dictionary in dailies:
			if key_b != "" and bool(r.get(key_b, false)):
				good_b += 1
		_row([item[0], "%d of %d" % [good_a, rows.size()], ("%d of %d" % [good_b, dailies.size()]) if key_b != "" else "-"])
	var wave_done: int = 0
	var draft_done: int = 0
	for r: Dictionary in rows:
		wave_done += 1 if bool(r["wave_restored"]) else 0
		draft_done += 1 if bool(r["draft_restored"]) else 0
	var wave_done_d: int = 0
	var draft_done_d: int = 0
	for r: Dictionary in dailies:
		wave_done_d += 1 if bool(r["wave_restored"]) else 0
		draft_done_d += 1 if bool(r["draft_restored"]) else 0
	_row(["Saves that really happened in the middle of a wave", "%d of %d" % [wave_done, rows.size()], "%d of %d" % [wave_done_d, dailies.size()]])
	_row(["Saves that really happened with a draft open", "%d of %d" % [draft_done, rows.size()], "%d of %d" % [draft_done_d, dailies.size()]])
	print("\nFailures: %s. Chain hash of the first process %s, of a second process %s: %s.\n" % [
		str(first["failures"]), "%d" % int(first["chain_hash"]), ("%d" % int(again["chain_hash"])) if again.has("chain_hash") else "missing",
		"equal" if again.has("chain_hash") and int(again["chain_hash"]) == int(first["chain_hash"]) else "NOT EQUAL"])
	var wins: int = 0
	for r: Dictionary in rows:
		wins += 1 if bool(r["won"]) else 0
	print("The plays used all 16 named strategies in turn, Normal and Relaxed, both pools; %d of the %d runs were wins, so the checks cover wins and losses.\n" % [wins, rows.size()])


# Win rates.

func _rates_tables() -> void:
	print("\n### Win rates by strategy (named strategies, %d seeds each)\n" % _seed_count("base_r0"))
	var ids: Array = []
	for r: Dictionary in _rates["base_r0"]:
		if not ids.has(r["strategy"]):
			ids.append(r["strategy"])
	var head: Array = ["Strategy"]
	for config: String in CONFIGS:
		head.append(CONFIG_NAMES[config])
	_head(head)
	for id: String in ids:
		var cells: Array = [id]
		for config: String in CONFIGS:
			var rows: Array = _where(_rates[config], func(r: Dictionary) -> bool: return r["strategy"] == id)
			cells.append(_rate(_won(rows), rows.size()))
		_row(cells)
	var all_cells: Array = ["**All 16**"]
	for config: String in CONFIGS:
		all_cells.append(_rate(_won(_rates[config]), _rates[config].size()))
	_row(all_cells)
	print("\nBy kind of strategy (the same plays, grouped):\n")
	_head(head)
	for group: Array in [["pick towers", "towers_"], ["pick economy", "economy_"], ["pick risk", "risk_"], ["pick random", "random_"]]:
		var cells: Array = [group[0]]
		for config: String in CONFIGS:
			var rows: Array = _where(_rates[config], func(r: Dictionary) -> bool: return String(r["strategy"]).begins_with(String(group[1])))
			cells.append(_rate(_won(rows), rows.size()))
		_row(cells)
	for group: Array in [["build wide", "_wide"], ["build tall", "_tall"]]:
		var cells2: Array = [group[0]]
		for config: String in CONFIGS:
			var rows2: Array = _where(_rates[config], func(r: Dictionary) -> bool: return String(r["strategy"]).contains(String(group[1])))
			cells2.append(_rate(_won(rows2), rows2.size()))
		_row(cells2)
	for group: Array in [["no early calls", false], ["early calls", true]]:
		var cells3: Array = [group[0]]
		for config: String in CONFIGS:
			var rows3: Array = _where(_rates[config], func(r: Dictionary) -> bool: return String(r["strategy"]).ends_with("_early") == bool(group[1]))
			cells3.append(_rate(_won(rows3), rows3.size()))
		_row(cells3)
	print("\nWhere the named strategies' runs end (Normal, no unlocks): waves cleared by lost runs\n")
	_head(["Waves cleared", "Runs lost there", "Share of all runs"])
	var lost: Dictionary = {}
	var total: int = 0
	for r: Dictionary in _rates["base_r0"]:
		total += 1
		if not bool(r["won"]):
			lost[int(r["cleared"])] = int(lost.get(int(r["cleared"]), 0)) + 1
	var keys: Array = lost.keys()
	keys.sort()
	for k: int in keys:
		_row(["%d (lost in wave %d)" % [k, k + 1], lost[k], _pct(int(lost[k]), total)])


func _seed_count(config: String) -> int:
	var seen: Dictionary = {}
	for r: Dictionary in _rates[config]:
		seen[int(r["i"])] = true
	return seen.size()


# The search.

func _search_tables() -> void:
	print("\n### Random strategy search (100 random strategies on each of seeds 1 to 50)\n")
	_head(["Setting", "Seeds with a winning strategy", "Strategies that win, of all tried", "Best lives (median over won seeds)", "Seeds with no win: waves cleared by the best"])
	for config: String in ["base_r0", "all_r0", "base_r1"]:
		var rows: Array = _load_rows("search_%s_" % config)
		if rows.is_empty():
			continue
		var won: int = 0
		var wins: int = 0
		var tried: int = 0
		var lives: Array = []
		var misses: Array = []
		for r: Dictionary in rows:
			tried += int(r["tried"])
			wins += int(r["wins"])
			if bool(r["best_won"]):
				won += 1
				lives.append(int(r["best_lives"]))
			else:
				misses.append("%d (seed %d, %s)" % [int(r["best_cleared"]), int(r["i"]), r["boss"]])
		_row([CONFIG_NAMES[config], _rate(won, rows.size()), _rate(wins, tried), "%d" % _quant(lives, 0.5), ", ".join(PackedStringArray(misses)) if misses.size() > 0 else "none"])
	print()


# Length.

func _length_tables() -> void:
	print("\n### Run length at 1x (wave time plus 15 s for each build phase)\n")
	_head(["Setting", "Plays", "Wins", "Won runs: mean min", "10th / 50th / 90th percentile", "Wave time only, mean min", "Share of won runs in 15 to 20 min", "Share in 12 to 15"])
	for config: String in CONFIGS:
		var rows: Array = _where(_rates[config], func(r: Dictionary) -> bool: return bool(r["won"]))
		var mins: Array = rows.map(func(r: Dictionary) -> float: return _minutes(r))
		var waves_only: Array = rows.map(func(r: Dictionary) -> float: return _wave_minutes(r))
		var inside: int = mins.filter(func(m: float) -> bool: return m >= 15.0 and m <= 20.0).size()
		var near: int = mins.filter(func(m: float) -> bool: return m >= 12.0 and m < 15.0).size()
		_row([CONFIG_NAMES[config], _rates[config].size(), rows.size(), "%.1f" % _mean(mins),
			"%.1f / %.1f / %.1f" % [_quant(mins, 0.1), _quant(mins, 0.5), _quant(mins, 0.9)], "%.1f" % _mean(waves_only), _pct(inside, rows.size()), _pct(near, rows.size())])
	print("\nWon runs by strategy kind (Normal, no unlocks), minutes:\n")
	_head(["Kind", "Won runs", "Mean min", "Build phases (mean)", "Early calls (mean)", "Wave time only, mean min"])
	for group: Array in [["no early calls", false], ["early calls", true]]:
		var rows2: Array = _where(_rates["base_r0"], func(r: Dictionary) -> bool: return bool(r["won"]) and String(r["strategy"]).ends_with("_early") == bool(group[1]))
		_row([group[0], rows2.size(), "%.1f" % _mean(rows2.map(func(r: Dictionary) -> float: return _minutes(r))),
			"%.1f" % _mean(rows2.map(func(r: Dictionary) -> float: return float(r["builds"]))),
			"%.1f" % _mean(rows2.map(func(r: Dictionary) -> float: return float(r["early"]))),
			"%.1f" % _mean(rows2.map(func(r: Dictionary) -> float: return _wave_minutes(r)))])
	print("\nWave time of won runs (Normal, no unlocks) by wave band, seconds per wave (no early calls):\n")
	_head(["Band", "Waves", "Mean seconds per wave"])
	var sums: Array = []
	var counts: Array = []
	for b: int in 6:
		sums.append(0.0)
		counts.append(0)
	for r: Dictionary in _rates["base_r0"]:
		if bool(r["won"]) and int(r["early"]) == 0:
			for w: int in mini(18, (r["wave_ticks"] as Array).size()):
				sums[w / 3] += float(r["wave_ticks"][w]) / 20.0
				counts[w / 3] += 1
	for b: int in 6:
		_row([b + 1, "%d to %d" % [b * 3 + 1, b * 3 + 3], "%.1f" % (float(sums[b]) / maxi(int(counts[b]), 1))])


# Waves: lives, gold, towers.

func _wave_tables() -> void:
	print("\n### Wave by wave (Normal, no unlocks, the named strategies without early calls)\n")
	var rows: Array = _where(_rates["base_r0"], func(r: Dictionary) -> bool: return int(r["early"]) == 0)
	_head(["Wave", "Plays that started it", "Lives lost in it (mean)", "Lost the run in it", "Gold unspent when it starts (median / mean)", "Share with nothing left to buy", "Income before it (median)", "Towers (mean)", "Tier sum (mean)", "Peak creatures (median / max)"])
	for w: int in 18:
		var reached: Array = _where(rows, func(r: Dictionary) -> bool: return (r["lives_at"] as Array).size() > w)
		if reached.is_empty():
			continue
		var lost: Array = []
		var gold: Array = []
		var idle: int = 0
		var towers: Array = []
		var tiers: Array = []
		var income: Array = []
		var peaks: Array = []
		var died: int = 0
		for r: Dictionary in reached:
			var next_lives: int = 0
			if (r["lives_pre"] as Array).size() > w + 1:
				next_lives = int(r["lives_pre"][w + 1])
			else:
				next_lives = int(r["lives"])
			lost.append(int(r["lives_at"][w]) - next_lives)
			if not bool(r["won"]) and int(r["reached"]) == w + 1:
				died += 1
			gold.append(int(r["gold_at"][w]))
			idle += int(r["idle_at"][w])
			towers.append(int(r["towers_at"][w]))
			tiers.append(int(r["tiers_at"][w]))
			if w > 0 and (r["gold_pre"] as Array).size() > w:
				income.append(int(r["gold_pre"][w]) - int(r["gold_at"][w - 1]))
			peaks.append(int(r["peak_at"][w]))
		_row([w + 1, reached.size(), "%.2f" % _mean(lost), _pct(died, reached.size()), "%d / %.0f" % [_quant(gold, 0.5), _mean(gold)], _pct(idle, reached.size()),
			"%d" % _quant(income, 0.5) if not income.is_empty() else "-", "%.1f" % _mean(towers), "%.1f" % _mean(tiers), "%d / %d" % [_quant(peaks, 0.5), _quant(peaks, 1.0)]])
	print("\nIncome before a wave is the gold at the start of its build phase less the gold left unspent at the start of the wave before, so it holds the clear bonus, bounties, early call bonuses and gold cards of the wave before.\n")
	print("\nThe same, won runs only: gold unspent when waves 10, 14, 16, 17 and 18 start, and the gold left at the end\n")
	_head(["Setting", "Won runs", "Wave 10", "Wave 14", "Wave 16", "Wave 17", "Wave 18", "End of run", "Nothing to buy at wave 18 start"])
	for config: String in CONFIGS:
		var won: Array = _where(_rates[config], func(r: Dictionary) -> bool: return bool(r["won"]) and int(r["early"]) == 0)
		if won.is_empty():
			continue
		var cells: Array = [CONFIG_NAMES[config], won.size()]
		for w: int in [9, 13, 15, 16, 17]:
			cells.append("%d" % _quant(won.map(func(r: Dictionary) -> int: return int(r["gold_at"][w])), 0.5))
		cells.append("%d" % _quant(won.map(func(r: Dictionary) -> int: return int(r["end_gold"])), 0.5))
		var idle18: int = 0
		for r: Dictionary in won:
			idle18 += int(r["idle_at"][17])
		cells.append(_pct(idle18, won.size()))
		_row(cells)
	print("\n(median gold unspent at the start of that wave, after the bot's purchases)\n")
	print("\nHow full the board is when the boss wave starts (runs that reached wave 18, Normal, no unlocks, no early calls):\n")
	_head(["Spots on the map", "Plays", "Towers built (mean)", "Every spot built", "Every tower at tier 3", "Gold unspent (median)"])
	var by_spots: Dictionary = {}
	for r: Dictionary in _where(rows, func(r: Dictionary) -> bool: return int(r["reached"]) >= 18):
		var spots: int = _spots_of(r)
		if not by_spots.has(spots):
			by_spots[spots] = []
		(by_spots[spots] as Array).append(r)
	var spot_keys: Array = by_spots.keys()
	spot_keys.sort()
	for spots: int in spot_keys:
		var list: Array = by_spots[spots]
		var full: int = 0
		var maxed: int = 0
		for r: Dictionary in list:
			if int(r["towers_at"][17]) >= spots:
				full += 1
			if int(r["tiers_at"][17]) >= 3 * int(r["towers_at"][17]):
				maxed += 1
		_row([spots, list.size(), "%.1f" % _mean(list.map(func(r: Dictionary) -> float: return float(r["towers_at"][17]))), _pct(full, list.size()), _pct(maxed, list.size()),
			"%d" % _quant(list.map(func(r: Dictionary) -> int: return int(r["gold_at"][17])), 0.5)])


var _spot_cache: Dictionary = {}


## Build spots on a play's map, from its stack.
func _spots_of(row: Dictionary) -> int:
	var key: String = String(row["stack"])
	if _spot_cache.has(key):
		return int(_spot_cache[key])
	var parts: PackedStringArray = key.split("|")
	var packs: Array[StringName] = []
	var plan: Dictionary = _plan(int(row["seed"]))
	packs.assign(plan["packs"])
	var level: LevelData = MapAssembler.build(_game.run, _game.catalog, StringName(parts[0]), StringName(parts[1]), StringName(parts[2]), packs)
	_spot_cache[key] = level.spots.size() if level != null else 0
	return int(_spot_cache[key])


# The boss wave.

func _boss_tables() -> void:
	print("
### The boss wave (wave 18)
")
	_head(["Setting", "Runs that started wave 18", "Won", "Lives when it starts (median)", "Won runs: lives lost in it (median)", "Won runs: boss reached the base", "Lost runs: boss health left at its lowest (median, of full)"])
	for config: String in CONFIGS:
		var rows: Array = _where(_rates[config], func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		if rows.is_empty():
			continue
		_row(_boss_row(CONFIG_NAMES[config], rows))
	print("
By boss (Normal, no unlocks, the named strategies):
")
	_head(["Boss", "Runs that started wave 18", "Won", "Lives when it starts (median)", "Won runs: lives lost in it (median)", "Won runs: boss reached the base", "Lost runs: boss health left at its lowest (median, of full)", "Lost runs: boss reached the base"])
	for boss: String in ["grumblesack", "ironshell", "moon_moth", "old_tusk"]:
		var rows2: Array = _where(_rates["base_r0"], func(r: Dictionary) -> bool: return r["boss"] == boss and int(r["reached"]) >= 18)
		if rows2.is_empty():
			continue
		var lost2: Array = _where(rows2, func(r: Dictionary) -> bool: return not bool(r["won"]))
		var reached: int = lost2.filter(func(r: Dictionary) -> bool: return int(r["boss_steps"]) == 0).size()
		var cells: Array = _boss_row(boss, rows2)
		cells.append(_rate(reached, lost2.size()))
		_row(cells)
	print("
A lost run's boss health is the lowest fraction of the boss's health seen (sampled every 5 ticks); a won run may have killed the boss or only outlived it: the reached the base column counts the wins where the boss got to the base and took its 20 lives. An empty cell means the boss was never seen on the map.
")


func _boss_row(label: String, rows: Array) -> Array:
	var lost: Array = _where(rows, func(r: Dictionary) -> bool: return not bool(r["won"]))
	var won: Array = _where(rows, func(r: Dictionary) -> bool: return bool(r["won"]))
	var left: Array = lost.filter(func(r: Dictionary) -> bool: return int(r["boss_min"]) >= 0).map(func(r: Dictionary) -> int: return int(r["boss_min"]))
	var lost_in: Array = won.map(func(r: Dictionary) -> int: return int(r["lives_at"][17]) - int(r["lives"]))
	var leaked: int = won.filter(func(r: Dictionary) -> bool: return int(r["boss_steps"]) == 0).size()
	return [label, rows.size(), _rate(won.size(), rows.size()), "%d" % _quant(rows.map(func(r: Dictionary) -> int: return int(r["lives_at"][17])), 0.5),
		("%d" % _quant(lost_in, 0.5)) if not lost_in.is_empty() else "-", _rate(leaked, won.size()), ("%.0f%%" % (_quant(left, 0.5) / 10.0)) if not left.is_empty() else "-"]


# Maps, bosses and packs.

func _map_tables() -> void:
	print("\n### Win rate by boss, map segment and stack (Normal, no unlocks, the named strategies)\n")
	var rows: Array = _rates["base_r0"]
	_head(["Boss", "Seeds", "Plays", "Won", "Mean waves cleared", "Lost by wave 6", "Lost in wave 18"])
	for boss: String in ["grumblesack", "ironshell", "moon_moth", "old_tusk"]:
		var list: Array = _where(rows, func(r: Dictionary) -> bool: return r["boss"] == boss)
		_row(_map_row(boss, list))
	for kind: Array in [["Top segment", 0], ["Middle segment", 1], ["Bottom segment", 2]]:
		print("\n%s:\n" % kind[0])
		_head([kind[0], "Seeds", "Plays", "Won", "Mean waves cleared", "Lost by wave 6", "Lost in wave 18"])
		var names: Array = []
		for r: Dictionary in rows:
			var piece: String = String(r["stack"]).split("|")[int(kind[1])]
			if not names.has(piece):
				names.append(piece)
		names.sort()
		for piece: String in names:
			var list2: Array = _where(rows, func(r: Dictionary) -> bool: return String(r["stack"]).split("|")[int(kind[1])] == piece)
			_row(_map_row(piece, list2))
	print("\nEvery stack with at least 4 seeds:\n")
	_head(["Stack (top, middle, bottom)", "Seeds", "Plays", "Won", "Mean waves cleared", "Lost by wave 6", "Lost in wave 18"])
	var stacks: Array = []
	for r: Dictionary in rows:
		if not stacks.has(r["stack"]):
			stacks.append(r["stack"])
	stacks.sort()
	for stack: String in stacks:
		var list3: Array = _where(rows, func(r: Dictionary) -> bool: return r["stack"] == stack)
		if _distinct_seeds(list3) >= 4:
			_row(_map_row(stack.replace("|", ", "), list3))
	print("\n### Packs: how often a run that reaches a pack's first wave fails to clear its last (Normal, no unlocks, the named strategies)\n")
	for band: int in range(1, 7):
		print("\nBand %d (waves %d to %d):\n" % [band, band * 3 - 2, band * 3])
		_head(["Pack", "Runs that reached it", "Lost inside it", "Mean lives lost in its waves (no early calls)"])
		var ids: Array = []
		for p: Dictionary in _game.run.packs_of(band):
			ids.append(String(p["id"]))
		for id: String in ids:
			var reached: int = 0
			var lost: int = 0
			var lives_lost: Array = []
			for r: Dictionary in rows:
				var packs: Array = _plan(int(r["seed"]))["packs"]
				if String(packs[band - 1]) != id:
					continue
				var first_wave: int = band * 3 - 3
				if int(r["reached"]) <= first_wave:
					continue
				reached += 1
				if not bool(r["won"]) and int(r["reached"]) <= band * 3:
					lost += 1
				if int(r["early"]) == 0:
					var sum: int = 0
					var complete: bool = true
					for w: int in range(first_wave, band * 3):
						if (r["lives_at"] as Array).size() <= w:
							complete = false
							break
						sum += int(r["lives_at"][w]) - (int(r["lives_pre"][w + 1]) if (r["lives_pre"] as Array).size() > w + 1 else int(r["lives"]))
					if complete:
						lives_lost.append(sum)
			_row([id, reached, _rate(lost, reached), "%.2f" % _mean(lives_lost) if not lives_lost.is_empty() else "-"])


func _distinct_seeds(rows: Array) -> int:
	var seen: Dictionary = {}
	for r: Dictionary in rows:
		seen[int(r["i"])] = true
	return seen.size()


func _map_row(label: String, list: Array) -> Array:
	var early: int = 0
	var boss_lost: int = 0
	for r: Dictionary in list:
		if not bool(r["won"]) and int(r["reached"]) <= 6:
			early += 1
		if not bool(r["won"]) and int(r["reached"]) >= 18:
			boss_lost += 1
	return [label, _distinct_seeds(list), list.size(), _rate(_won(list), list.size()), "%.1f" % _mean(list.map(func(r: Dictionary) -> float: return float(r["cleared"]))), _pct(early, list.size()), _pct(boss_lost, list.size())]


# Towers in won runs.

func _tower_tables() -> void:
	print("\n### Towers and paths standing at the end of won runs\n")
	for config: String in ["base_r0", "all_r0"]:
		var won: Array = _where(_rates[config], func(r: Dictionary) -> bool: return bool(r["won"]))
		print("\n%s (%d won runs):\n" % [CONFIG_NAMES[config], won.size()])
		_head(["Tower or path", "Won runs with at least one", "Mean built"])
		var keys: Array = []
		for r: Dictionary in won:
			for k: String in (r["mix"] as Dictionary).keys():
				if not keys.has(k):
					keys.append(k)
		keys.sort()
		for k: String in keys:
			var has: int = 0
			var total: int = 0
			for r: Dictionary in won:
				var n: int = int((r["mix"] as Dictionary).get(k, 0))
				total += n
				has += 1 if n > 0 else 0
			_row([k, _pct(has, won.size()), "%.2f" % (float(total) / won.size())])


# Cards.

func _card_tables() -> void:
	print("\n### Cards: offered, picked and win rate\n")
	for config: String in ["base_r0", "all_r0"]:
		var rows: Array = _rates[config]
		if rows.is_empty():
			continue
		var base_rate: float = float(_won(rows)) / rows.size()
		var random_rows: Array = _where(rows, func(r: Dictionary) -> bool: return String(r["strategy"]).begins_with("random_"))
		print("\n%s. Win rate of all plays %s. The last two columns use only the four random-pick strategies, where the pick does not depend on the card: the win rate of runs that picked the card against runs that were offered it and did not pick it.\n" % [CONFIG_NAMES[config], _pct(_won(rows), rows.size())])
		_head(["Card", "Times offered", "Times picked", "Pick rate", "Win rate of runs that picked it", "Random picks: picked", "Random picks: offered, not picked"])
		for c: int in _cards.size():
			var offered: int = 0
			var picked: int = 0
			var picked_runs: int = 0
			var picked_wins: int = 0
			for r: Dictionary in rows:
				var seen: bool = false
				for list: Array in r["offered"]:
					if _has(list, c):
						offered += 1
						seen = true
				if _has(r["picks"], c):
					picked_runs += 1
					picked_wins += 1 if bool(r["won"]) else 0
				picked += _count(r["picks"], c)
			var in_picked: int = 0
			var in_picked_won: int = 0
			var out_picked: int = 0
			var out_picked_won: int = 0
			for r: Dictionary in random_rows:
				var was_offered: bool = false
				for list2: Array in r["offered"]:
					was_offered = was_offered or _has(list2, c)
				if not was_offered:
					continue
				if _has(r["picks"], c):
					in_picked += 1
					in_picked_won += 1 if bool(r["won"]) else 0
				else:
					out_picked += 1
					out_picked_won += 1 if bool(r["won"]) else 0
			if offered == 0:
				continue
			_row([_cards[c], offered, picked, _pct(picked, offered), _rate(picked_wins, picked_runs), _rate(in_picked_won, in_picked), _rate(out_picked_won, out_picked)])
		print()


## JSON numbers read back as floats, so card indexes are compared as ints.
func _has(list: Array, c: int) -> bool:
	return _count(list, c) > 0


func _count(list: Array, c: int) -> int:
	var n: int = 0
	for v: Variant in list:
		if int(v) == c:
			n += 1
	return n


# What each card is worth, from the saved-draft experiment.

func _cardvalue_tables() -> void:
	for pool: String in ["base", "all"]:
		var rows: Array = _load_rows_named("cardvalue_%s_" % pool)
		if rows.is_empty():
			continue
		print("
### What each card is worth, %s (%d drafts, each offered card taken in turn and the run played on)
" % ["no unlocks" if pool == "base" else "all cards", rows.size()])
		print("Each draft was saved before the pick. Each of its 3 offered cards was then taken and the same random-picking strategy played the run to its end. A card's gain is its outcome less the average outcome of the 3 cards offered in that draft, so it needs no correction for how strong the run was at that draft. Win gain is in points of win rate. Lives gain is in lives left at the end (0 for a loss). The three right columns split the win gain by draft: picks 1 to 6, 7 to 12, 13 to 17.
")
		_head(["Card", "Times offered", "Win gain (points)", "Lives gain", "Waves cleared gain", "Win gain, picks 1 to 6", "Picks 7 to 12", "Picks 13 to 17"])
		var stats: Dictionary = {}
		for r: Dictionary in rows:
			var outcomes: Array = r["outcomes"]
			var win_mean: float = 0.0
			var lives_mean: float = 0.0
			var cleared_mean: float = 0.0
			for o: Dictionary in outcomes:
				win_mean += 1.0 if bool(o["won"]) else 0.0
				lives_mean += float(o["lives"])
				cleared_mean += float(o["cleared"])
			win_mean /= outcomes.size()
			lives_mean /= outcomes.size()
			cleared_mean /= outcomes.size()
			var stage: int = 0 if int(r["k"]) < 6 else (1 if int(r["k"]) < 12 else 2)
			for o: Dictionary in outcomes:
				var id: String = o["card"]
				if not stats.has(id):
					stats[id] = {"n": 0, "win": 0.0, "lives": 0.0, "cleared": 0.0, "sn": [0, 0, 0], "sw": [0.0, 0.0, 0.0]}
				var item: Dictionary = stats[id]
				item["n"] = int(item["n"]) + 1
				var gain: float = (1.0 if bool(o["won"]) else 0.0) - win_mean
				item["win"] = float(item["win"]) + gain
				item["lives"] = float(item["lives"]) + float(o["lives"]) - lives_mean
				item["cleared"] = float(item["cleared"]) + float(o["cleared"]) - cleared_mean
				item["sn"][stage] = int(item["sn"][stage]) + 1
				item["sw"][stage] = float(item["sw"][stage]) + gain
		var ids: Array = stats.keys()
		ids.sort_custom(func(a: String, b: String) -> bool: return float(stats[a]["win"]) / int(stats[a]["n"]) > float(stats[b]["win"]) / int(stats[b]["n"]))
		for id: String in ids:
			var item2: Dictionary = stats[id]
			var n: int = int(item2["n"])
			var cells: Array = [id, n, "%+.1f" % (100.0 * float(item2["win"]) / n), "%+.1f" % (float(item2["lives"]) / n), "%+.2f" % (float(item2["cleared"]) / n)]
			for stage: int in 3:
				var sn: int = int(item2["sn"][stage])
				cells.append(("%+.1f (n %d)" % [100.0 * float(item2["sw"][stage]) / sn, sn]) if sn > 0 else "-")
			_row(cells)
		print()


func _load_rows_named(prefix: String) -> Array:
	return _load_rows(prefix)


# The daily.

func _daily_tables() -> void:
	print("\n### The daily: the next 400 days (2026-10-25 to 2027-11-28)\n")
	var days: Array = _load_rows("daily_")
	if days.is_empty():
		print("(no daily files)")
		return
	var named: int = 0
	var extra_tried: int = 0
	var extra_won: int = 0
	var unwon: Array = []
	for d: Dictionary in days:
		var won_named: bool = false
		for p: Dictionary in d["plays"]:
			won_named = won_named or bool(p["won"])
		if won_named:
			named += 1
		elif d.has("extra"):
			extra_tried += 1
			if bool(d["extra"]["won"]):
				extra_won += 1
			else:
				unwon.append(d)
		else:
			unwon.append(d)
	_head(["Measure", "Days"])
	_row(["Days played", days.size()])
	_row(["Won by at least one of the 16 named strategies", _rate(named, days.size())])
	_row(["Not won by a named strategy, won by one of 100 random strategies", _rate(extra_won, days.size() - named)])
	_row(["Won by some strategy in all", _rate(named + extra_won, days.size())])
	_row(["Not won by any strategy tried", _rate(unwon.size(), days.size())])
	print("\nPer strategy, share of the %d days won:\n" % days.size())
	_head(["Strategy", "Days won"])
	var ids: Array = []
	for p: Dictionary in days[0]["plays"]:
		ids.append(p["strategy"])
	for id: String in ids:
		var won: int = 0
		for d: Dictionary in days:
			for p: Dictionary in d["plays"]:
				if p["strategy"] == id and bool(p["won"]):
					won += 1
		_row([id, _rate(won, days.size())])
	var every: Array = []
	for d: Dictionary in days:
		for p: Dictionary in d["plays"]:
			every.append(p)
	_row(["**All 16**", _rate(_won(every), every.size())])
	print("\nBy boss:\n")
	_head(["Boss", "Days", "Won by a named strategy", "Won by any tried", "Share of the 16 plays that won"])
	for boss: String in ["grumblesack", "ironshell", "moon_moth", "old_tusk"]:
		var list: Array = _where(days, func(d: Dictionary) -> bool: return d["boss"] == boss)
		var any_named: int = 0
		var any_all: int = 0
		var plays: Array = []
		for d: Dictionary in list:
			var won_named: bool = false
			for p: Dictionary in d["plays"]:
				won_named = won_named or bool(p["won"])
				plays.append(p)
			any_named += 1 if won_named else 0
			any_all += 1 if (won_named or (d.has("extra") and bool(d["extra"]["won"]))) else 0
		_row([boss, list.size(), _rate(any_named, list.size()), _rate(any_all, list.size()), _pct(_won(plays), plays.size())])
	print("\nDays no strategy won (%d):\n" % unwon.size())
	if not unwon.is_empty():
		_head(["Day", "Seed", "Stack", "Boss", "Most waves cleared by a named strategy", "Best random strategy: waves cleared (of 100 tried)"])
		for d: Dictionary in unwon:
			var best: int = 0
			for p: Dictionary in d["plays"]:
				best = maxi(best, int(p["cleared"]))
			_row([d["day"], int(d["seed"]), String(d["stack"]).replace("|", ", "), d["boss"], best, str(int(d["extra"]["cleared"])) if d.has("extra") else "-"])
	var deep_rows: Array = []
	for file: String in _files("deep_"):
		deep_rows.append_array(_read(file)["rows"])
	if not deep_rows.is_empty():
		print("\nThe unwon days again, with more random strategies each (400 for all ten, then 1500 for the four that stayed unwon):\n")
		_head(["Day", "Stack", "Boss", "Strategies tried", "Won", "Most waves cleared", "Lives left if won"])
		var by_day: Dictionary = {}
		for line: Dictionary in deep_rows:
			if not by_day.has(line["day"]) or int(line["found"]["tried"]) >= int(by_day[line["day"]]["found"]["tried"]):
				by_day[line["day"]] = line
		var keys: Array = by_day.keys()
		keys.sort()
		for day: String in keys:
			var f: Dictionary = by_day[day]["found"]
			_row([day, String(by_day[day]["stack"]).replace("|", ", "), by_day[day]["boss"], int(f["tried"]), "yes" if bool(f["won"]) else "no", int(f["cleared"]), int(f["lives"]) if bool(f["won"]) else "-"])
	print("\nLongest run of days in a row that some strategy won: %d. Longest run of days that none won: %d.\n" % _streaks(days))


func _streaks(days: Array) -> Array:
	var best_won: int = 0
	var best_lost: int = 0
	var run_won: int = 0
	var run_lost: int = 0
	for d: Dictionary in days:
		var any: bool = d.has("extra") and bool(d["extra"]["won"])
		for p: Dictionary in d["plays"]:
			any = any or bool(p["won"])
		if any:
			run_won += 1
			run_lost = 0
		else:
			run_lost += 1
			run_won = 0
		best_won = maxi(best_won, run_won)
		best_lost = maxi(best_lost, run_lost)
	return [best_won, best_lost]


# The risk cards.

func _risk_tables() -> void:
	print("\n### Risk cards: creatures on the map at once\n")
	var static_data: Dictionary = _read("static.json")
	if not static_data.is_empty():
		print("What a pack wave spawns with each risk card (`RunPacks.spawn_total`, a Puffball counts with its Puffs, the 120 bound of RULES 14.3 applies to every pack wave with any one card):\n")
		var cards: Array = ["none", "crowded_night", "thick_hides", "hurry_night", "gateless_night", "flock", "moonlit_wager", "crasher_escort", "pip_parade"]
		_head(["Card", "Largest wave (creatures)", "Where", "Packs waves at 80 or more", "Over 120"])
		for card: String in cards:
			var best: int = 0
			var where: String = ""
			var big: int = 0
			var over: int = 0
			for line: Dictionary in static_data["spawn"]:
				var n: int = int(line[card])
				if n > best:
					best = n
					where = "%s wave %d" % [line["pack"], int(line["wave"])]
				big += 1 if n >= 80 else 0
				over += 1 if n > 120 else 0
			_row([card, best, where, big, over])
	for file: String in _files("risk_"):
		var data: Dictionary = _read(file)
		var rows: Array = data["rows"]
		print("\nPlayed peaks. Baseline play: `%s` on seeds %d to %d (%d plays; Normal, every card). Before each wave from 2 to 17 the battle was saved, then that wave was played again with each risk card on it, on the same towers, with no more buying. Peak is the most creatures on the map at once during that wave and any wave it overlapped.\n" % [data["strategy"], int(data["first"]), int(data["first"]) + int(data["count"]) - 1, int(data["count"])])
		_head(["Card", "Waves played", "Peak: median", "Peak: 90th percentile", "Peak: most", "Where (seed index, wave)", "Peak, waves 12 to 17: median / most", "Lives lost (mean)", "Gold gained (mean)", "Runs lost in the wave"])
		for card: String in ["none", "crowded_night", "thick_hides", "hurry_night", "gateless_night", "flock", "moonlit_wager", "crasher_escort", "pip_parade"]:
			var list: Array = _where(rows, func(r: Dictionary) -> bool: return r["card"] == card and not r.has("bad_branch"))
			if list.is_empty():
				continue
			var peaks: Array = list.map(func(r: Dictionary) -> int: return int(r["peak"]))
			var late: Array = _where(list, func(r: Dictionary) -> bool: return int(r["wave"]) >= 11).map(func(r: Dictionary) -> int: return int(r["peak"]))
			var worst: Dictionary = list[0]
			for r: Dictionary in list:
				if int(r["peak"]) > int(worst["peak"]):
					worst = r
			var lost: int = list.filter(func(r: Dictionary) -> bool: return bool(r["lost"])).size()
			_row([card, list.size(), "%d" % _quant(peaks, 0.5), "%d" % _quant(peaks, 0.9), peaks.max(), "(%d, %d)" % [int(worst["i"]), int(worst["wave"]) + 1],
				("%d / %d" % [_quant(late, 0.5), late.max()]) if not late.is_empty() else "-",
				"%.2f" % _mean(list.map(func(r: Dictionary) -> float: return float(r["lives_lost"]))), "%.0f" % _mean(list.map(func(r: Dictionary) -> float: return float(r["gold_gain"]))), _pct(lost, list.size())])
	print()


# What-ifs: other RunData numbers (tweak=...).

func _whatif_tables() -> void:
	var files: Array[String] = _files("whatif_")
	if files.is_empty():
		return
	print("\n### What-ifs on run numbers\n")
	_head(["What-if", "Setting", "Plays", "Won", "Won runs: mean min", "Reached wave 18", "Won of those"])
	var base: Dictionary = _read("rates_base_r0_1.json")
	if not base.is_empty():
		var base_rows: Array = base["rows"]
		var base_won: Array = _where(base_rows, func(r: Dictionary) -> bool: return bool(r["won"]))
		var base_boss: Array = _where(base_rows, func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		_row(["none (the report's numbers, same seeds)", "Normal, base", base_rows.size(), _rate(base_won.size(), base_rows.size()), "%.1f" % _mean(base_won.map(func(r: Dictionary) -> float: return _minutes(r))),
			_rate(base_boss.size(), base_rows.size()), _rate(base_won.size(), base_boss.size())])
	for file: String in files:
		var data: Dictionary = _read(file)
		var rows: Array = data["rows"]
		var won: Array = _where(rows, func(r: Dictionary) -> bool: return bool(r["won"]))
		var boss: Array = _where(rows, func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		_row([data.get("tweak", "-"), "%s, %s" % ["Relaxed" if bool(data["relaxed"]) else "Normal", data["pool"]], rows.size(), _rate(won.size(), rows.size()),
			"%.1f" % _mean(won.map(func(r: Dictionary) -> float: return _minutes(r))) if not won.is_empty() else "-", _rate(boss.size(), rows.size()), _rate(won.size(), boss.size())])
	print()


# Ironshell at armor 10 (commit c015b05) against armor 6 (the commit measured).

func _ironshell_tables() -> void:
	if _files("ironshell_").is_empty():
		return
	print("
### Ironshell runs again at armor 10 (commit c015b05), same seeds and strategies
")
	_head(["Setting", "Plays", "Won at armor 6", "Won at armor 10", "Started wave 18 (armor 10)", "Won of those, armor 6", "Won of those, armor 10"])
	for config: String in CONFIGS:
		var fresh: Array = _read("ironshell_%s.json" % config).get("rows", [])
		if fresh.is_empty():
			continue
		var old: Array = _where(_rates[config], func(r: Dictionary) -> bool: return r["boss"] == "ironshell")
		var old_boss: Array = _where(old, func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		var new_boss: Array = _where(fresh, func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		_row([CONFIG_NAMES[config], fresh.size(), _rate(_won(old), old.size()), _rate(_won(fresh), fresh.size()), new_boss.size(), _rate(_won(old_boss), old_boss.size()), _rate(_won(new_boss), new_boss.size())])
	var old_days: Array = []
	for d: Dictionary in _load_rows("daily_"):
		if d["boss"] == "ironshell":
			old_days.append(d)
	var new_days: Array = _load_rows("ironshell_daily_")
	if not new_days.is_empty():
		print("
The daily, Ironshell days (%d days):
" % new_days.size())
		_head(["Armor", "Days won by a named strategy", "Days won by any (named, then up to 100 random)", "Plays won, of 16 a day"])
		for item: Array in [["6", old_days], ["10", new_days]]:
			var named: int = 0
			var any: int = 0
			var plays: Array = []
			for d: Dictionary in item[1]:
				var w: bool = false
				for p: Dictionary in d["plays"]:
					w = w or bool(p["won"])
					plays.append(p)
				named += 1 if w else 0
				any += 1 if (w or (d.has("extra") and bool(d["extra"]["won"]))) else 0
			_row([item[0], _rate(named, item[1].size()), _rate(any, item[1].size()), _pct(_won(plays), plays.size())])
	print()


# Lives and Tea Break.

func _lives_tables() -> void:
	print("
### Lives decide the boss wave (Normal, the named strategies)
")
	for config: String in ["base_r0", "all_r0"]:
		var rows: Array = _where(_rates[config], func(r: Dictionary) -> bool: return int(r["reached"]) >= 18)
		print("
%s: runs that started wave 18, by lives when it started:
" % CONFIG_NAMES[config])
		_head(["Lives at the start of wave 18", "Runs", "Won", "Of the wins, boss reached the base"])
		for band: Array in [[0, 10], [11, 20], [21, 25], [26, 30], [31, 1000]]:
			var list: Array = _where(rows, func(r: Dictionary) -> bool: return int(r["lives_at"][17]) >= int(band[0]) and int(r["lives_at"][17]) <= int(band[1]))
			var won: Array = _where(list, func(r: Dictionary) -> bool: return bool(r["won"]))
			var leaked: int = won.filter(func(r: Dictionary) -> bool: return int(r["boss_steps"]) == 0).size()
			_row(["%d to %d" % [band[0], band[1]] if int(band[1]) < 1000 else "%d or more" % band[0], list.size(), _rate(won.size(), list.size()), _rate(leaked, won.size())])
	print("
By the Tea Break cards a run picked (all plays, Normal):
")
	_head(["Setting", "Tea Breaks picked", "Plays", "Won"])
	var tea: int = _cards.find("tea_break")
	for config: String in ["base_r0", "all_r0"]:
		for n: int in 7:
			var list2: Array = _where(_rates[config], func(r: Dictionary) -> bool: return _count(r["picks"], tea) == n if n < 6 else _count(r["picks"], tea) >= 6)
			if not list2.is_empty():
				_row([CONFIG_NAMES[config], str(n) if n < 6 else "6 or more", list2.size(), _rate(_won(list2), list2.size())])
