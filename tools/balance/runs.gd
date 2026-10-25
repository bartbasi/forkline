# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## The run and daily runner (task B2). One job per process, so many can run side by side.
##
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=rates first=1 count=50 pool=base relaxed=0 out=PATH
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=det first=1 count=50 out=PATH
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=daily from=0 count=400 out=PATH
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=search first=1 count=50 n=200 pool=base relaxed=0 out=PATH
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=risk first=1 count=20 strat=towers_wide out=PATH
##   godot --headless --path . --script res://tools/balance/runs.gd -- mode=static out=PATH
##
## mode=rates: every strategy (or strats=id,id) plays run seeds seed_of(first) to seed_of(first + count - 1).
##   pool=base is the pool with no unlocks, pool=all every card. relaxed=1 plays Relaxed.
## mode=det: the same-seed checks (docs/balance/README.md "Runs").
## mode=daily: day offsets from to from + count - 1, counted from 2026-10-25 (offset 0). Always Normal and every card.
## rates and daily also take boss=ironshell: only the seeds (days) whose run has that boss.
## mode=search: n random strategies (RunBot.random_strategy, seeded from the run seed) play each run seed.
## mode=daily also takes extra=N: a day no named strategy wins gets up to N random strategies, until one wins.
## mode=cardvalue: a strategy (strats=a,b alternate by seed) plays a run; before each pick the state is saved, and each of the
##   3 offered cards is taken in turn and the run played on to its end by the same strategy (pool=base or all).
## mode=deep: days=2026-11-11,2026-12-01 n=1000: n random strategies on each listed day (the days the daily run left unwon).
## mode=risk: snapshots of one strategy's run before each wave, then each risk card applied to that wave.
## mode=static: the stacks, the packs and the most creatures a pack wave spawns with each risk card.
## Any mode takes bakery_min=1 (a bot builds a Bakery that reaches only 1 spot; default 2).
## Any mode takes tweak=strength_step:8,strength_start:100,start_gold:300,gates:1,tea_break:5 (RunData numbers and the lives of Tea Break, in memory only).
## The result is one JSON object, written to `out` and printed after "RESULT ".

const RunBot: GDScript = preload("res://tools/balance/run_bot.gd")
const DAILY_FIRST: Dictionary = {"year": 2026, "month": 10, "day": 25, "hour": 0, "minute": 0, "second": 0}

var _args: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2:
			_args[parts[0]] = parts[1]
	var game: GameData = GameData.load_from("res://data")
	if not game.problems.is_empty() or game.run == null:
		printerr("data problems: %s" % ", ".join(game.problems))
		quit(2)
		return
	RunBot.set_bakery_min(int(_args.get("bakery_min", "2")))
	var tweak: String = String(_args.get("tweak", ""))
	if tweak != "" and not _apply_tweak(game, tweak):
		return
	var started: int = Time.get_ticks_msec()
	var mode: String = String(_args.get("mode", "rates"))
	var first: int = int(_args.get("first", "1"))
	var count: int = int(_args.get("count", "50"))
	var result: Dictionary = {}
	if mode == "rates":
		result = _rates(game, first, count)
	elif mode == "det":
		result = _det(game, first, count)
	elif mode == "daily":
		result = _daily(game, int(_args.get("from", "0")), count)
	elif mode == "search":
		result = _search(game, first, count)
	elif mode == "risk":
		result = _risk(game, first, count)
	elif mode == "deep":
		result = _deep(game)
	elif mode == "cardvalue":
		result = _cardvalue(game, first, count)
	elif mode == "static":
		result = _static(game)
	else:
		printerr("unknown mode %s" % mode)
		quit(2)
		return
	if result.has("bad"):
		printerr(String(result["bad"]))
		quit(2)
		return
	result["mode"] = mode
	result["seconds"] = (Time.get_ticks_msec() - started) / 1000.0
	if tweak != "":
		result["tweak"] = tweak
	if RunBot.get_bakery_min() != 2:
		result["tweak"] = (String(result.get("tweak", "")) + " bakery_min:%d" % RunBot.get_bakery_min()).strip_edges()
	var text: String = JSON.stringify(result)
	print("RESULT " + text.substr(0, 300))
	var out: String = String(_args.get("out", ""))
	if out != "":
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			printerr("cannot write %s" % out)
			quit(2)
			return
		file.store_string(text)
		file.close()
	quit(0)


## The i-th run seed: i times 2654435761, modulo 2^32. A spread of seeds like the ones a phone draws.
static func seed_of(i: int) -> int:
	return (i * 2654435761) % 4294967296


## The day key `offset` days after 2026-10-25 (offset 0 is the day after this report is dated).
static func day_of(offset: int) -> String:
	var unix: int = Time.get_unix_time_from_datetime_dict(DAILY_FIRST) + offset * 86400
	return RunSeeds.day_key(Time.get_date_dict_from_unix_time(unix))


func _apply_tweak(game: GameData, tweak: String) -> bool:
	for item: String in tweak.split(","):
		var parts: PackedStringArray = item.split(":")
		if parts.size() != 2:
			printerr("bad tweak %s" % item)
			quit(2)
			return false
		var value: int = int(parts[1])
		match parts[0]:
			"strength_step":
				game.run.strength_step = value
			"strength_start":
				game.run.strength_start = value
			"start_gold":
				game.run.start_gold = value
			"gates":
				game.run.gates = value
			"tea_break":
				# The lives Tea Break gives, in the held card data (what-if only).
				for card: Dictionary in game.run.cards:
					if card["id"] == &"tea_break":
						card["effects"][0]["amount"] = value
			_:
				printerr("unknown tweak %s" % parts[0])
				quit(2)
				return false
	return true


func _pool(game: GameData, which: String) -> Array[StringName]:
	if which == "all":
		return game.run.card_ids()
	return game.run.pool({})


func _stack(game: GameData, run_seed: int) -> Dictionary:
	var plan: Dictionary = MapAssembler.plan(run_seed, game.run)
	var packs: Array[String] = []
	for id: StringName in plan["packs"]:
		packs.append(String(id))
	return {"top": String(plan["top"]), "middle": String(plan["middle"]), "bottom": String(plan["bottom"]),
		"boss": String(plan["boss"]), "packs": packs}


func _card_ids(game: GameData) -> Array:
	var out: Array = []
	for id: StringName in game.run.card_ids():
		out.append(String(id))
	return out


# Win rates.

func _rates(game: GameData, first: int, count: int) -> Dictionary:
	var relaxed: bool = String(_args.get("relaxed", "0")) == "1"
	var which: String = String(_args.get("pool", "base"))
	var pool: Array[StringName] = _pool(game, which)
	var chosen: Array[Dictionary] = RunBot.strategies()
	var wanted: String = String(_args.get("strats", "all"))
	if wanted != "all":
		var list: PackedStringArray = wanted.split(",")
		chosen = []
		for id: String in list:
			var strat: Dictionary = RunBot.strategy(id)
			if strat.is_empty():
				return {"bad": "unknown strategy %s" % id}
			chosen.append(strat)
	var cards: Array = _card_ids(game)
	var only_boss: String = String(_args.get("boss", ""))
	var rows: Array = []
	for i: int in range(first, first + count):
		var run_seed: int = seed_of(i)
		var stack: Dictionary = _stack(game, run_seed)
		if only_boss != "" and stack["boss"] != only_boss:
			continue
		for strat: Dictionary in chosen:
			var row: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat)
			if row.has("bad"):
				return row
			row["i"] = i
			row["stack"] = "%s|%s|%s" % [stack["top"], stack["middle"], stack["bottom"]]
			row["boss"] = stack["boss"]
			_pack_cards(row, cards)
			rows.append(row)
	return {"relaxed": relaxed, "pool": which, "pool_size": pool.size(), "cards": cards, "first": first, "count": count, "rows": rows}


## Card ids become their index in cards.json order, so a file stays small.
func _pack_cards(row: Dictionary, cards: Array) -> void:
	var picks: Array = []
	for id: Variant in row["picks"]:
		picks.append(cards.find(String(id)))
	row["picks"] = picks
	var offered: Array = []
	for list: Array in row["offered"]:
		var coded: Array = []
		for id: Variant in list:
			coded.append(cards.find(String(id)))
		offered.append(coded)
	row["offered"] = offered
	row.erase("battle_hash")
	row.erase("run_hash")
	row.erase("restores")
	row.erase("offers_equal")


# The same seed plays the same.

func _det(game: GameData, first: int, count: int) -> Dictionary:
	var strats: Array[Dictionary] = RunBot.strategies()
	var all_cards: Array[StringName] = game.run.card_ids()
	var base_cards: Array[StringName] = game.run.pool({})
	var rows: Array = []
	var chain: String = ""
	var failures: Array = []
	for i: int in range(first, first + count):
		var run_seed: int = seed_of(i)
		var k: int = i - first
		var strat: Dictionary = strats[k % strats.size()]
		var relaxed: bool = k % 4 >= 2
		var pool: Array[StringName] = all_cards if k % 2 == 0 else base_cards
		var row: Dictionary = {"i": i, "seed": run_seed, "strategy": String(strat["id"]), "relaxed": relaxed, "pool": "all" if k % 2 == 0 else "base"}
		# The map, the waves and the picks of the seed, built twice.
		var plan_a: Dictionary = MapAssembler.plan(run_seed, game.run)
		var plan_b: Dictionary = MapAssembler.plan(run_seed, game.run)
		var level_a: LevelData = MapAssembler.assemble(run_seed, game.run, game.catalog)
		var level_b: LevelData = MapAssembler.assemble(run_seed, game.run, game.catalog)
		var text_a: String = JSON.stringify(level_a.to_data())
		row["map_equal"] = JSON.stringify(plan_a) == JSON.stringify(plan_b) and text_a == JSON.stringify(level_b.to_data())
		row["map_hash"] = text_a.hash()
		# The same play twice, then with a save and load in the middle of a wave, then with a draft open.
		var a: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat)
		var b: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat)
		var wave_at: int = clampi(2 + k % 12, 0, int(a["reached"]) - 1)
		var c: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat, {"restore_wave": [wave_at, 60 + 40 * (k % 5)]})
		var draft_at: int = clampi(1 + k % 12, 0, maxi(a["picks"].size() - 1, 0))
		var d: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat, {"restore_draft": draft_at})
		row["again_equal"] = _same(a, b)
		row["wave_restore_equal"] = _same(a, c)
		row["wave_restored"] = int(c.get("restores", 0)) == 1
		row["draft_restore_equal"] = _same(a, d) and bool(d.get("offers_equal", false))
		row["draft_restored"] = int(d.get("restores", 0)) == 1
		row["won"] = a["won"]
		row["cleared"] = a["cleared"]
		row["offers_hash"] = JSON.stringify(a["offered"]).hash()
		row["battle_hash"] = a["battle_hash"]
		row["run_hash"] = a["run_hash"]
		if not (row["map_equal"] and row["again_equal"] and row["wave_restore_equal"] and row["draft_restore_equal"]):
			failures.append(i)
		chain += "%d:%d:%d:%d;" % [row["map_hash"], row["offers_hash"], row["battle_hash"], row["run_hash"]]
		rows.append(row)
	# Dailies: the first days after the report, played twice and with the same two saves.
	var daily_rows: Array = []
	for n: int in mini(count, 50):
		var day: String = day_of(n)
		var daily_seed: int = RunSeeds.daily_seed(day)
		var strat: Dictionary = strats[n % strats.size()]
		var a: Dictionary = RunBot.play(game, daily_seed, day, false, all_cards, strat)
		var b: Dictionary = RunBot.play(game, daily_seed, day, false, all_cards, strat)
		var c: Dictionary = RunBot.play(game, daily_seed, day, false, all_cards, strat, {"restore_wave": [clampi(3 + n % 10, 0, int(a["reached"]) - 1), 100]})
		var d: Dictionary = RunBot.play(game, daily_seed, day, false, all_cards, strat, {"restore_draft": clampi(2 + n % 10, 0, maxi(a["picks"].size() - 1, 0))})
		var drow: Dictionary = {"day": day, "seed": daily_seed, "strategy": String(strat["id"]),
			"again_equal": _same(a, b), "wave_restore_equal": _same(a, c), "wave_restored": int(c.get("restores", 0)) == 1,
			"draft_restore_equal": _same(a, d) and bool(d.get("offers_equal", false)), "draft_restored": int(d.get("restores", 0)) == 1,
			"won": a["won"], "battle_hash": a["battle_hash"], "run_hash": a["run_hash"]}
		if not (drow["again_equal"] and drow["wave_restore_equal"] and drow["draft_restore_equal"]):
			failures.append(day)
		chain += "%s:%d:%d;" % [day, drow["battle_hash"], drow["run_hash"]]
		daily_rows.append(drow)
	return {"first": first, "count": count, "rows": rows, "daily_rows": daily_rows, "failures": failures, "chain_hash": chain.hash()}


## Two plays are the same when every field matches, except the count of restores they made.
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.has("bad") or b.has("bad") or a.has("restore_failed") or b.has("restore_failed"):
		return false
	var x: Dictionary = a.duplicate()
	var y: Dictionary = b.duplicate()
	for key: String in ["restores", "offers_equal"]:
		x.erase(key)
		y.erase(key)
	return JSON.stringify(x) == JSON.stringify(y)


# The daily.

func _daily(game: GameData, from: int, count: int) -> Dictionary:
	var extra: int = int(_args.get("extra", "0"))
	var cards: Array = _card_ids(game)
	var pool: Array[StringName] = game.run.card_ids()
	var chosen: Array[Dictionary] = RunBot.strategies()
	var rows: Array = []
	for n: int in range(from, from + count):
		var day: String = day_of(n)
		var daily_seed: int = RunSeeds.daily_seed(day)
		var stack: Dictionary = _stack(game, daily_seed)
		if String(_args.get("boss", "")) != "" and stack["boss"] != String(_args.get("boss", "")):
			continue
		var plays: Array = []
		for strat: Dictionary in chosen:
			var row: Dictionary = RunBot.play(game, daily_seed, day, false, pool, strat)
			if row.has("bad"):
				return row
			_pack_cards(row, cards)
			plays.append({"strategy": row["strategy"], "won": row["won"], "lives": row["lives"], "cleared": row["cleared"], "reached": row["reached"],
				"ticks": row["ticks"], "builds": row["builds"], "risks": row["risks"], "early": row["early"], "peak": row["peak"]})
		var won_any: bool = false
		for play: Dictionary in plays:
			won_any = won_any or bool(play["won"])
		var line: Dictionary = {"n": n, "day": day, "seed": daily_seed, "stack": "%s|%s|%s" % [stack["top"], stack["middle"], stack["bottom"]],
			"boss": stack["boss"], "plays": plays}
		if not won_any and extra > 0:
			line["extra"] = _extra(game, daily_seed, day, false, pool, extra)
		rows.append(line)
	return {"from": from, "count": count, "extra": extra, "rows": rows}


## Random strategies on one seed, until one wins or n are tried. {"tried", "won", "lives", "cleared", "strategy"}
## (the winner, or the one that cleared the most waves).
func _extra(game: GameData, run_seed: int, day: String, relaxed: bool, pool: Array[StringName], n: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ("%d:search" % run_seed).hash()
	var best: Dictionary = {}
	var best_strat: Dictionary = {}
	var tried: int = 0
	for k: int in n:
		var strat: Dictionary = RunBot.random_strategy(rng, "x%d" % k)
		var row: Dictionary = RunBot.play(game, run_seed, day, relaxed, pool, strat)
		tried += 1
		if best.is_empty() or _better(row, best):
			best = row
			best_strat = strat
		if bool(row["won"]):
			break
	return {"tried": tried, "won": best["won"], "lives": best["lives"], "cleared": best["cleared"], "strategy": best_strat}


func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["won"]) != bool(b["won"]):
		return bool(a["won"])
	if bool(a["won"]):
		return int(a["lives"]) > int(b["lives"])
	return int(a["cleared"]) > int(b["cleared"]) or (int(a["cleared"]) == int(b["cleared"]) and int(a["lives"]) > int(b["lives"]))


# A search on run seeds: n random strategies each.

func _search(game: GameData, first: int, count: int) -> Dictionary:
	var relaxed: bool = String(_args.get("relaxed", "0")) == "1"
	var which: String = String(_args.get("pool", "base"))
	var pool: Array[StringName] = _pool(game, which)
	var n: int = int(_args.get("n", "200"))
	var rows: Array = []
	for i: int in range(first, first + count):
		var run_seed: int = seed_of(i)
		var stack: Dictionary = _stack(game, run_seed)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = ("%d:search" % run_seed).hash()
		var wins: int = 0
		var best: Dictionary = {}
		var best_strat: Dictionary = {}
		var lives_sum: int = 0
		for k: int in n:
			var strat: Dictionary = RunBot.random_strategy(rng, "x%d" % k)
			var row: Dictionary = RunBot.play(game, run_seed, "", relaxed, pool, strat)
			if row.has("bad"):
				return row
			if bool(row["won"]):
				wins += 1
				lives_sum += int(row["lives"])
			if best.is_empty() or _better(row, best):
				best = row
				best_strat = strat
		rows.append({"i": i, "seed": run_seed, "stack": "%s|%s|%s" % [stack["top"], stack["middle"], stack["bottom"]], "boss": stack["boss"],
			"tried": n, "wins": wins, "best_won": best["won"], "best_lives": best["lives"], "best_cleared": best["cleared"], "best_ticks": best["ticks"],
			"best_strategy": best_strat})
	return {"relaxed": relaxed, "pool": which, "n": n, "first": first, "count": count, "rows": rows}


# Days nobody won.

func _deep(game: GameData) -> Dictionary:
	var pool: Array[StringName] = game.run.card_ids()
	var n: int = int(_args.get("n", "1000"))
	var rows: Array = []
	for day: String in String(_args.get("days", "")).split(","):
		if not RunSeeds.is_day_key(day):
			return {"bad": "not a day key: %s" % day}
		var daily_seed: int = RunSeeds.daily_seed(day)
		var stack: Dictionary = _stack(game, daily_seed)
		var found: Dictionary = _extra(game, daily_seed, day, false, pool, n)
		rows.append({"day": day, "seed": daily_seed, "stack": "%s|%s|%s" % [stack["top"], stack["middle"], stack["bottom"]], "boss": stack["boss"], "found": found})
	return {"n": n, "rows": rows}


# What each card is worth.

func _cardvalue(game: GameData, first: int, count: int) -> Dictionary:
	var which: String = String(_args.get("pool", "base"))
	var pool: Array[StringName] = _pool(game, which)
	var names: PackedStringArray = String(_args.get("strats", "random_wide,random_tall")).split(",")
	var rows: Array = []
	for i: int in range(first, first + count):
		var run_seed: int = seed_of(i)
		var strat: Dictionary = RunBot.strategy(names[(i - first) % names.size()])
		if strat.is_empty():
			return {"bad": "unknown strategy"}
		var base: Dictionary = RunBot.play(game, run_seed, "", false, pool, strat, {"draft_snapshots": true})
		if base.has("bad"):
			return base
		for snap: Dictionary in base["draft_snaps"]:
			var outcomes: Array = []
			for card: StringName in snap["offers"]:
				var res: Dictionary = RunBot.play(game, run_seed, "", false, pool, strat, {"resume": snap, "force": card})
				if res.has("bad"):
					return res
				outcomes.append({"card": String(card), "won": res["won"], "lives": res["lives"], "cleared": res["cleared"]})
			rows.append({"i": i, "strategy": String(strat["id"]), "k": snap["k"], "outcomes": outcomes})
	return {"pool": which, "first": first, "count": count, "rows": rows}


# Peak creatures with each risk card.

func _risk(game: GameData, first: int, count: int) -> Dictionary:
	var strat: Dictionary = RunBot.strategy(String(_args.get("strat", "towers_wide")))
	if strat.is_empty():
		return {"bad": "unknown strategy"}
	var pool: Array[StringName] = game.run.card_ids()
	var risk_cards: Array[Dictionary] = []
	for card: Dictionary in game.run.cards:
		if card["kind"] == &"risk":
			risk_cards.append(card)
	var rows: Array = []
	var bases: Array = []
	for i: int in range(first, first + count):
		var run_seed: int = seed_of(i)
		var base: Dictionary = RunBot.play(game, run_seed, "", false, pool, strat, {"snapshots": true})
		if base.has("bad"):
			return base
		bases.append({"i": i, "seed": run_seed, "won": base["won"], "cleared": base["cleared"], "lives": base["lives"]})
		for snap: Dictionary in base["snapshots"]:
			var wave: int = int(snap["wave"])
			# A risk card can change waves 2 to 17 (14.4): the draft after wave 1 is the first.
			if wave < 1 or wave > 16:
				continue
			var kinds: Array = [null]
			kinds.append_array(risk_cards)
			for card: Variant in kinds:
				var line: Dictionary = _branch(game, snap, wave, card)
				line["i"] = i
				line["wave"] = wave
				line["card"] = "none" if card == null else String((card as Dictionary)["id"])
				rows.append(line)
	return {"strategy": String(strat["id"]), "first": first, "count": count, "bases": bases, "rows": rows}


## One wave from a snapshot: optionally a risk card on it, then step until the wave is over.
func _branch(game: GameData, snap: Dictionary, wave: int, card: Variant) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(snap["battle"]))
	var b: Battle = Battle.from_data(parsed, game.catalog)
	if b == null:
		return {"bad_branch": true}
	b.record_events = false
	if card != null:
		var effects: Array[Dictionary] = []
		effects.append_array((card as Dictionary)["effects"])
		if b.add_effects(effects, true) != Battle.DONE:
			return {"bad_branch": true}
	var lives_before: int = b.lives
	var gold_before: int = b.gold
	var peak: int = 0
	if b.start_next_wave() != Battle.DONE:
		return {"bad_branch": true}
	var from_tick: int = b.tick
	while b.phase == Battle.Phase.WAVE and b.tick - from_tick < 12000:
		b.step()
		peak = maxi(peak, b.enemies.size())
	return {"peak": peak, "lives_lost": lives_before - b.lives, "gold_gain": b.gold - gold_before, "ticks": b.tick - from_tick,
		"lost": b.phase == Battle.Phase.LOST}


# Maps and packs.

func _static(game: GameData) -> Dictionary:
	var data: RunData = game.run
	var risk: Array[Dictionary] = []
	for card: Dictionary in data.cards:
		if card["kind"] == &"risk":
			risk.append(card)
	var spawn: Array = []
	for pack: Dictionary in data.packs:
		for w: int in 3:
			var groups: Array = pack["waves"][w]["groups"]
			var line: Dictionary = {"pack": String(pack["id"]), "band": pack["band"], "boss": String(pack["boss"]), "wave": (int(pack["band"]) - 1) * 3 + w + 1,
				"none": RunPacks.spawn_total(groups, game.catalog, [])}
			for card: Dictionary in risk:
				var effects: Array[Dictionary] = []
				effects.append_array(card["effects"])
				line[String(card["id"])] = RunPacks.spawn_total(groups, game.catalog, effects)
			spawn.append(line)
	# Every stack that fits, with the chance a seed picks it: tops evenly, then the middles that fit, then the bottoms.
	var stacks: Array = []
	var tops: Array[Dictionary] = data.segments_of(&"top")
	var first_packs: Array[StringName] = []
	for band: int in range(1, RunData.BANDS + 1):
		first_packs.append(data.packs_of(band, data.boss_ids()[0] if band == RunData.BANDS else &"")[0]["id"])
	for top: Dictionary in tops:
		var middles: Array[Dictionary] = data.segments_under(top["id"])
		for middle: Dictionary in middles:
			var bottoms: Array[Dictionary] = data.segments_under(middle["id"])
			for bottom: Dictionary in bottoms:
				var level: LevelData = MapAssembler.build(data, game.catalog, top["id"], middle["id"], bottom["id"], first_packs)
				var chance: float = 1.0 / tops.size() / middles.size() / bottoms.size()
				stacks.append({"top": String(top["id"]), "middle": String(middle["id"]), "bottom": String(bottom["id"]),
					"spots": level.spots.size() if level != null else -1, "sockets": level.sockets.size() if level != null else -1,
					"entrances": level.entrances.size() if level != null else -1, "chance": chance})
	var packs_per_band: Array = []
	for band: int in range(1, RunData.BANDS + 1):
		packs_per_band.append(data.packs_of(band).size())
	return {"spawn": spawn, "stacks": stacks, "packs_per_band": packs_per_band, "bosses": _names(data.boss_ids())}


func _names(ids: Array[StringName]) -> Array:
	var out: Array = []
	for id: StringName in ids:
		out.append(String(id))
	return out
