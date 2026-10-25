# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## The run bot (task B2). It plays a roguelite run or a daily through RunSession and the Battle it
## wraps, with the public API only (docs/ARCHITECTURE.md 3.3). All chance in a bot comes from one
## RandomNumberGenerator seeded from the run seed and the strategy id, so a play can be repeated.
##
## A strategy is a Dictionary {"id", "pick", "build", "early"}:
##   pick:  how it chooses a card.
##     towers   a tower card first, then a perk, a spare gate, an economy card, a risk card last.
##     economy  a tower card only while the run has fewer than 2 kinds of tower, then economy, tower, perk, gate, risk last.
##     risk     a risk card whenever one is offered, then tower, perk, economy, gate.
##     random   any offered card, evenly.
##     Within a kind the card is chosen evenly by the bot's generator.
##   build: how it spends.
##     wide     builds new towers first (4 + 0.7 per wave started, up to the spots), upgrades after.
##     tall     upgrades what it has first (2 + 1 per 4 waves started towers wanted), builds after.
##   early: calls the next wave early from wave 4 on, when 6 or fewer creatures are on the map.
## A searched strategy (random_strategy) has pick "custom" with its own "order" of card kinds, and its own
## "base" and "rate" (towers wanted = base + rate per wave started), "early_from" and "early_live".
## Every strategy places gates (the socket that puts the most spots within 2.5 tiles of the walking
## route), buys during waves as gold comes in, never moves a gate and sells only to make room for a
## tower type it has never built.
##
## Run state ("st") is plain data and holds no Battle, so a restored battle can carry on with the same bot.

const TICK_CAP: int = 72000                       # 60 minutes of wave time: far past a run. A play that hits it is "stuck".
const BUILD_SECONDS: int = 15                     # a build phase counts 15 s in a run's length (RULES 12.5)
const REACH: int = 250                            # 2.5 tiles: the road a spot "sees", as in the plain recipe (RULES 12.6)
## Spots a Bakery must reach (within 1.5 tiles) before a bot builds one. 2 as in the plain recipe (RULES 12.6); runs.gd
## sets it from bakery_min= for the what-if with 1.
static var bakery_min: int = 2


static func set_bakery_min(n: int) -> void:
	bakery_min = n


static func get_bakery_min() -> int:
	return bakery_min


const PICKS: Array[StringName] = [&"towers", &"economy", &"risk", &"random"]
const BUILDS: Array[StringName] = [&"wide", &"tall"]
const BASE_WEIGHT: Dictionary = {
	&"sling_post": 1.5, &"pumpkin_catapult": 1.0, &"longbow_loft": 1.0, &"firework_tower": 0.7,
	&"lullaby_bell": 0.8, &"bakery": 0.8,
}
const CAPS: Dictionary = {&"lullaby_bell": 2, &"bakery": 1}
const PRIORITY: Dictionary = {
	&"towers": [&"tower", &"perk", &"gate", &"economy", &"risk"],
	&"economy": [&"economy", &"tower", &"perk", &"gate", &"risk"],
	&"risk": [&"risk", &"tower", &"perk", &"economy", &"gate"],
}


## The 16 strategies, in a fixed order: pick style, then build style, then early calls off and on.
static func strategies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pick: StringName in PICKS:
		for build: StringName in BUILDS:
			for early: bool in [false, true]:
				out.append({"id": "%s_%s%s" % [pick, build, "_early" if early else ""], "pick": pick, "build": build, "early": early})
	return out


## A random strategy for a search, from the generator: a card order, a build pace and an early call habit.
static func random_strategy(rng: RandomNumberGenerator, id: String) -> Dictionary:
	var order: Array[StringName] = [&"tower", &"perk", &"gate", &"economy", &"risk"]
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: StringName = order[i]
		order[i] = order[j]
		order[j] = tmp
	var early: bool = rng.randf() < 0.3
	return {"id": id, "pick": &"custom", "build": &"param", "order": order, "base": rng.randf_range(2.0, 6.0), "rate": rng.randf_range(0.1, 1.0),
		"early": early, "early_from": rng.randi_range(2, 8), "early_live": [0, 3, 6, 10, 15][rng.randi_range(0, 4)]}


## The strategy with this id, or {}.
static func strategy(id: String) -> Dictionary:
	for item: Dictionary in strategies():
		if String(item["id"]) == id:
			return item
	return {}


# State.

static func new_state(session: RunSession, strat: Dictionary, run_seed: int) -> Dictionary:
	var b: Battle = session.battle
	var level: LevelData = b.level
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ("%d:%s:bot" % [run_seed, String(strat["id"])]).hash()
	# Per bot tastes: a jitter on each tower's weight and which tier 3 path each tower takes.
	var weight: Dictionary = {}
	var spec_of: Dictionary = {}
	for id: StringName in BASE_WEIGHT.keys():
		weight[id] = float(BASE_WEIGHT[id]) * rng.randf_range(0.7, 1.3)
		spec_of[id] = rng.randi_range(0, 1)
	# Spots ranked by the road they see, most first, ties in cell order (as RULES 12.6 step 1).
	var road: Array[Vector2i] = []
	for r: int in level.rows:
		for c: int in Sim.MAP_COLUMNS:
			if level.is_road(Vector2i(c, r)):
				road.append(Vector2i(c, r))
	var keyed: Array = []
	for i: int in level.spots.size():
		var seen: int = 0
		for cell: Vector2i in road:
			var dx: int = (cell.x - level.spots[i].x) * 100
			var dy: int = (cell.y - level.spots[i].y) * 100
			if dx * dx + dy * dy <= REACH * REACH:
				seen += 1
		keyed.append([-seen, i])
	keyed.sort()
	var ranked: Array[Vector2i] = []
	for item: Array in keyed:
		ranked.append(level.spots[int(item[1])])
	# For each road cell, how many spots are within 2.5 tiles: what a gate steers walkers past.
	var cover: Dictionary = {}
	for cell: Vector2i in road:
		var n: int = 0
		for spot: Vector2i in level.spots:
			var dx: int = (cell.x - spot.x) * 100
			var dy: int = (cell.y - spot.y) * 100
			if dx * dx + dy * dy <= REACH * REACH:
				n += 1
		cover[cell] = n
	return {"strat": strat, "rng": rng, "weight": weight, "spec_of": spec_of, "ranked": ranked, "cover": cover,
		"dead": {}, "gate_dead": {}, "swapped": {}}


# Cards.

## The card the strategy takes from the open draft.
static func choose(st: Dictionary, session: RunSession, offers: Array[StringName]) -> StringName:
	var rng: RandomNumberGenerator = st["rng"]
	var style: StringName = st["strat"]["pick"]
	if style == &"random":
		return offers[rng.randi_range(0, offers.size() - 1)]
	var order: Array = st["strat"]["order"] if style == &"custom" else PRIORITY[style]
	if style == &"economy" and _kinds_of_tower(session) < 2:
		order = [&"tower", &"economy", &"perk", &"gate", &"risk"]
	for kind: StringName in order:
		var same: Array[StringName] = []
		for id: StringName in offers:
			if session.card(id).get("kind", &"") == kind:
				same.append(id)
		if not same.is_empty():
			return _weighted(st, session, same, rng)
	return offers[0]


## A card among those of one kind. Tower cards and perks lean to the tower's weight (attackers over Bells and
## Bakeries); the rest are even.
static func _weighted(st: Dictionary, session: RunSession, same: Array[StringName], rng: RandomNumberGenerator) -> StringName:
	var weights: Array[float] = []
	var total: float = 0.0
	for id: StringName in same:
		var tower: StringName = StringName(session.card(id).get("tower", &""))
		var w: float = float(st["weight"].get(tower, 1.0))
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i: int in same.size():
		roll -= weights[i]
		if roll <= 0.0:
			return same[i]
	return same[same.size() - 1]


## The towers the run has: the level's, plus the tower of every tower card picked.
static func run_towers(session: RunSession) -> Array[StringName]:
	var out: Array[StringName] = session.battle.level.towers.duplicate()
	for id: StringName in session.picks:
		var card: Dictionary = session.card(id)
		if card.get("kind", &"") == &"tower" and not out.has(card["tower"]):
			out.append(card["tower"])
	return out


static func _kinds_of_tower(session: RunSession) -> int:
	return run_towers(session).size()


# Gates.

## Puts the gates in hand on the sockets that raise the walking route's cover the most. A gate
## that would not raise it stays in hand. Build phases only.
static func place_gates(st: Dictionary, session: RunSession) -> void:
	var b: Battle = session.battle
	while b.phase == Battle.Phase.BUILD and b.gates_in_hand > 0:
		var closed: Array[Vector2i] = b.closed_cells()
		var now: int = _route_cover(st, b, closed)
		var best: Vector2i = Vector2i(-1, -1)
		var best_score: int = now
		for socket: Vector2i in b.level.sockets:
			if closed.has(socket) or st["gate_dead"].has(socket):
				continue
			var shut: Array[Vector2i] = closed.duplicate()
			shut.append(socket)
			if b.seals(shut):
				continue
			var score: int = _route_cover(st, b, shut)
			if score > best_score:
				best_score = score
				best = socket
		if best == Vector2i(-1, -1):
			return
		if b.place_gate(best) != Battle.DONE:
			st["gate_dead"][best] = true


static func _route_cover(st: Dictionary, b: Battle, closed: Array[Vector2i]) -> int:
	var cover: Dictionary = st["cover"]
	var total: int = 0
	for route: Dictionary in b.routes(closed):
		for cell: Vector2i in route["walk"]:
			total += int(cover.get(cell, 0))
	return total


# Buying.

## Buys while gold lasts. Returns &"waiting" (the next item costs too much), or &"nothing" (nothing
## left to buy or build).
static func buy(st: Dictionary, session: RunSession) -> StringName:
	var b: Battle = session.battle
	var guard: int = 0
	while guard < 200:
		guard += 1
		var step: Dictionary = _next_step(st, session)
		if step.is_empty():
			return &"nothing"
		var refusal: StringName
		match String(step["do"]):
			"build":
				refusal = b.place_tower(step["cell"], step["type"])
			"upgrade":
				refusal = b.upgrade_tower(step["cell"], int(step["spec"]))
			_:
				refusal = b.sell_tower(step["cell"])
				if refusal == Battle.DONE:
					st["swapped"][step["type"]] = true
		if refusal == &"too_poor":
			return &"waiting"
		if refusal != Battle.DONE:
			st["dead"][step["key"]] = true
	return &"nothing"


## The next thing to buy: {"do": "build"/"upgrade"/"sell", "cell", "type", "spec", "key"}, or {}.
static func _next_step(st: Dictionary, session: RunSession) -> Dictionary:
	var b: Battle = session.battle
	var level: LevelData = b.level
	var dead: Dictionary = st["dead"]
	var ranked: Array[Vector2i] = st["ranked"]
	var weight: Dictionary = st["weight"]
	var available: Array[StringName] = run_towers(session)
	var count: Dictionary = {}
	for id: StringName in available:
		count[id] = 0
	for tower: TowerState in b.towers:
		count[tower.type] = int(count.get(tower.type, 0)) + 1
	var free: Array[Vector2i] = []
	for spot: Vector2i in ranked:
		if b.tower_at(spot) == null:
			free.append(spot)
	var waves: int = b.waves_started
	var strat: Dictionary = st["strat"]
	var wide: bool = strat["build"] == &"wide"
	var want: int = mini(ranked.size(), (4 + int(0.7 * waves)) if wide else (2 + waves / 4))
	if strat.has("base"):
		want = mini(ranked.size(), int(float(strat["base"]) + float(strat["rate"]) * waves))
	# A type never built goes first. With no spot free (or no good Bakery spot free) it sells one tower to make room.
	for id: StringName in available:
		if int(count[id]) > 0 or dead.has("t:" + String(id)):
			continue
		var cell: Vector2i = _spot_for(id, free, ranked)
		if cell != Vector2i(-1, -1):
			var made: String = "b:%d,%d:%s" % [cell.x, cell.y, id]
			if dead.has(made):
				dead["t:" + String(id)] = true
				continue
			return {"do": "build", "cell": cell, "type": id, "spec": -1, "key": made}
		if id == &"bakery":
			var any: Vector2i = _spot_for(id, ranked, ranked)
			if any == Vector2i(-1, -1):
				dead["t:" + String(id)] = true
				continue
			if b.phase == Battle.Phase.BUILD and not st["swapped"].has(id) and b.tower_at(any) != null:
				return {"do": "sell", "cell": any, "type": id, "spec": -1, "key": "s:%d,%d" % [any.x, any.y]}
		elif free.is_empty() and b.phase == Battle.Phase.BUILD and not st["swapped"].has(id):
			var victim: TowerState = _weakest(b, count)
			if victim != null:
				return {"do": "sell", "cell": victim.cell, "type": id, "spec": -1, "key": "s:%d,%d" % [victim.cell.x, victim.cell.y]}
	var upgrade: Dictionary = _upgrade_step(st, session)
	var type: StringName = _deficit(available, count, weight, dead)
	if not free.is_empty() and type != &"" and (b.towers.size() < want or upgrade.is_empty()):
		var cell2: Vector2i = _spot_for(type, free, ranked)
		if cell2 != Vector2i(-1, -1):
			var key: String = "b:%d,%d:%s" % [cell2.x, cell2.y, type]
			if not dead.has(key):
				return {"do": "build", "cell": cell2, "type": type, "spec": -1, "key": key}
	return upgrade


## The tower to upgrade: lowest tier first, attackers before Bells and Bakeries, best spot first.
static func _upgrade_step(st: Dictionary, session: RunSession) -> Dictionary:
	var b: Battle = session.battle
	var ranked: Array[Vector2i] = st["ranked"]
	var best: TowerState = null
	var best_key: int = 0
	for tower: TowerState in b.towers:
		if tower.tier >= 3:
			continue
		var key: String = "u:%d,%d:%d" % [tower.cell.x, tower.cell.y, tower.tier]
		if st["dead"].has(key):
			continue
		var support: int = 0 if tower.kind == &"attack" else 1
		var rank_key: int = tower.tier * 1000 + support * 100 + ranked.find(tower.cell)
		if best == null or rank_key < best_key:
			best = tower
			best_key = rank_key
	if best == null:
		return {}
	var spec: int = -1
	if best.tier == 2:
		spec = int(st["spec_of"][best.type])
	return {"do": "upgrade", "cell": best.cell, "type": best.type, "spec": spec, "key": "u:%d,%d:%d" % [best.cell.x, best.cell.y, best.tier]}


## The type to build next: the one with the lowest count over weight, skipping capped types. &"" for none.
static func _deficit(available: Array[StringName], count: Dictionary, weight: Dictionary, dead: Dictionary) -> StringName:
	var best: StringName = &""
	var best_score: float = 0.0
	for id: StringName in available:
		if (CAPS.has(id) and int(count[id]) >= int(CAPS[id])) or dead.has("t:" + String(id)):
			continue
		var score: float = float(count[id]) / float(weight[id])
		if best == &"" or score < best_score:
			best = id
			best_score = score
	return best


## Where a tower of this type goes: attackers on the best free spot, a Bell on the best free spot
## after the top two, a Bakery on the free spot with the most neighboring spots (at least 2).
static func _spot_for(type: StringName, free: Array[Vector2i], ranked: Array[Vector2i]) -> Vector2i:
	if free.is_empty():
		return Vector2i(-1, -1)
	if type == &"bakery":
		var best: Vector2i = Vector2i(-1, -1)
		var most: int = bakery_min - 1
		for spot: Vector2i in free:
			var near: int = 0
			for other: Vector2i in ranked:
				if other != spot and absi(other.x - spot.x) <= 1 and absi(other.y - spot.y) <= 1:
					near += 1
			if near > most:
				most = near
				best = spot
		return best
	if type == &"lullaby_bell":
		for spot: Vector2i in free:
			if ranked.find(spot) >= 2:
				return spot
	return free[0]


## The tower to sell to make room: of the commonest type (at least 2 of it), the lowest tier, then the worst spot.
static func _weakest(b: Battle, count: Dictionary) -> TowerState:
	var common: StringName = &""
	var most: int = 1
	for id: StringName in count.keys():
		if int(count[id]) > most:
			most = int(count[id])
			common = id
	if common == &"":
		return null
	var victim: TowerState = null
	for tower: TowerState in b.towers:
		if tower.type != common:
			continue
		if victim == null or tower.tier < victim.tier or (tower.tier == victim.tier and Sim.cell_before(victim.cell, tower.cell)):
			victim = tower
	return victim


# Playing.

## Plays one run to its end. The pool, seed, day and difficulty are given; `opts` may hold
##   "restore_wave": [w, k]   save and load (through JSON text) k ticks after wave w (0 based) starts
##   "restore_draft": n       save and load when the draft after n picks is open
##   "snapshots": true        keep the saved state before each wave starts (for the risk branches)
##   "draft_snapshots": true  keep the saved state (and the bot's generator) before each pick (for the card experiment)
##   "resume": Dictionary     carry on from a draft snapshot; "force" is then the card taken first
## Returns a plain Dictionary (see the keys at the end).
static func play(game: GameData, run_seed: int, day: String, relaxed: bool, pool: Array[StringName], strat: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var session: RunSession = null
	var st: Dictionary = {}
	if opts.has("resume"):
		var saved: Dictionary = opts["resume"]
		var battle_in: Battle = Battle.from_data(JSON.parse_string(JSON.stringify(saved["battle"])), game.catalog)
		session = RunSession.from_data(JSON.parse_string(JSON.stringify(saved["run"])), battle_in, game.run) if battle_in != null else null
		if session == null:
			return {"bad": "a draft snapshot would not load at seed %d" % run_seed}
		st = new_state(session, strat, run_seed)
		(st["rng"] as RandomNumberGenerator).state = int(saved["rng_state"])
		st["dead"] = (saved["dead"] as Dictionary).duplicate()
		st["gate_dead"] = (saved["gate_dead"] as Dictionary).duplicate()
		st["swapped"] = (saved["swapped"] as Dictionary).duplicate()
	else:
		session = RunSession.start(run_seed, day, relaxed, pool, game.run, game.catalog)
		if session == null:
			return {"bad": "RunSession.start gave null for seed %d" % run_seed}
		st = new_state(session, strat, run_seed)
	var b: Battle = session.battle
	b.record_events = false
	var forced: StringName = StringName(opts.get("force", ""))
	var draft_snaps: Array = []
	var wave_count: int = b.wave_count()
	var early_on: bool = bool(strat["early"])
	var calls: int = 0
	var builds: int = 0
	var peak: int = 0
	var peak_at: Array[int] = []
	var gold_at: Array[int] = []
	var gold_pre: Array[int] = []
	var lives_pre: Array[int] = []
	var lives_at: Array[int] = []
	var towers_at: Array[int] = []
	var tiers_at: Array[int] = []
	var idle_at: Array[int] = []
	var wave_ticks: Array[int] = []
	var offered: Array = []
	var snapshots: Array = []
	var restores: int = 0
	var offers_equal: bool = true
	var boss_min: int = 1000
	var boss_steps: int = -1
	var boss_seen: bool = false
	var restore_wave: Array = opts.get("restore_wave", [])
	var restore_draft: int = int(opts.get("restore_draft", -1))
	var spent_total: int = 0
	var idle: StringName = &"waiting"
	var boss_dist: PackedInt32Array = b.map.distances(b.closed_cells())
	while b.phase == Battle.Phase.BUILD and b.tick < TICK_CAP:
		gold_pre.append(b.gold)
		lives_pre.append(b.lives)
		while session.draft_open():
			if restore_draft == session.picks.size() and restores == 0:
				var before: Array[StringName] = session.offers()
				var again: Dictionary = _roundtrip(game, session)
				if again.is_empty():
					return {"restore_failed": true, "won": false, "seed": run_seed}
				session = again["session"]
				b = session.battle
				b.record_events = false
				restores += 1
				if session.offers() != before:
					offers_equal = false
			var offers: Array[StringName] = session.offers()
			offered.append(offers.duplicate())
			if bool(opts.get("draft_snapshots", false)):
				draft_snaps.append({"battle": b.to_data(), "run": session.to_data(), "rng_state": (st["rng"] as RandomNumberGenerator).state,
					"dead": (st["dead"] as Dictionary).duplicate(), "gate_dead": (st["gate_dead"] as Dictionary).duplicate(),
					"swapped": (st["swapped"] as Dictionary).duplicate(), "offers": offers.duplicate(), "k": session.picks.size()})
			var choice: StringName = choose(st, session, offers) if forced == &"" else forced
			forced = &""
			if session.pick(choice) != Battle.DONE:
				choice = offers[0]
				if session.pick(choice) != Battle.DONE:
					return {"bad": "pick refused at seed %d" % run_seed}
		place_gates(st, session)
		var gold_before: int = b.gold
		idle = buy(st, session)
		spent_total += gold_before - b.gold
		builds += 1
		gold_at.append(b.gold)
		lives_at.append(b.lives)
		towers_at.append(b.towers.size())
		tiers_at.append(_tier_sum(b))
		idle_at.append(1 if idle == &"nothing" else 0)
		if bool(opts.get("snapshots", false)):
			snapshots.append({"battle": b.to_data(), "run": session.to_data(), "wave": b.waves_started})
		var started_at: int = b.tick
		if session.start_next_wave() != Battle.DONE:
			break
		wave_ticks.append(0)
		peak_at.append(0)
		var first_tick: int = started_at
		var index: int = wave_ticks.size() - 1
		while b.phase == Battle.Phase.WAVE and b.tick < TICK_CAP:
			if b.tick % 4 == 0:
				idle = buy(st, session)
			if early_on and b.waves_started < wave_count and b.waves_started >= int(strat.get("early_from", 3)) and b.enemies.size() <= int(strat.get("early_live", 6)) and b.tick % 2 == 0:
				if session.start_next_wave() == Battle.DONE:
					calls += 1
					gold_at.append(b.gold)
					lives_at.append(b.lives)
					towers_at.append(b.towers.size())
					tiers_at.append(_tier_sum(b))
					idle_at.append(1 if idle == &"nothing" else 0)
					wave_ticks[index] = b.tick - first_tick
					wave_ticks.append(0)
					peak_at.append(0)
					index = wave_ticks.size() - 1
					first_tick = b.tick
			if restore_wave.size() == 2 and restores == 0 and b.waves_started == int(restore_wave[0]) + 1 and b.tick - first_tick >= int(restore_wave[1]):
				var moved: Dictionary = _roundtrip(game, session)
				if moved.is_empty():
					return {"restore_failed": true, "won": false, "seed": run_seed}
				session = moved["session"]
				b = session.battle
				b.record_events = false
				restores += 1
			b.step()
			var live: int = b.enemies.size()
			if live > peak:
				peak = live
			if live > peak_at[index]:
				peak_at[index] = live
			if b.tick % 5 == 0:
				for enemy: EnemyState in b.enemies:
					if game.catalog.enemy(enemy.type).boss:
						boss_seen = true
						boss_min = mini(boss_min, enemy.health * 1000 / maxi(enemy.max_health, 1))
						var left: int = boss_dist[(enemy.pos.y / Sim.UNIT) * Sim.MAP_COLUMNS + enemy.pos.x / Sim.UNIT]
						boss_steps = left if boss_steps < 0 else mini(boss_steps, left)
		wave_ticks[index] = b.tick - first_tick
	var res: Dictionary = session.result()
	var mix: Dictionary = {}
	for tower: TowerState in b.towers:
		var key: String = String(tower.type)
		mix[key] = int(mix.get(key, 0)) + 1
		if tower.tier == 3:
			var path: String = String(game.catalog.tower(tower.type).specs[tower.spec])
			mix[path] = int(mix.get(path, 0)) + 1
	var picks: Array[String] = []
	for id: StringName in session.picks:
		picks.append(String(id))
	var out: Dictionary = {
		"seed": run_seed, "day": day, "relaxed": relaxed, "strategy": String(strat["id"]),
		"won": res["won"], "lives": res["lives"], "cleared": res["waves"], "reached": res["reached"], "risks": res["risks"],
		"ticks": b.tick, "builds": builds, "early": calls, "peak": peak, "peak_at": peak_at,
		"stuck": b.phase == Battle.Phase.WAVE or b.phase == Battle.Phase.BUILD,
		"gold_pre": gold_pre, "lives_pre": lives_pre, "gold_at": gold_at, "lives_at": lives_at, "towers_at": towers_at, "tiers_at": tiers_at, "idle_at": idle_at,
		"wave_ticks": wave_ticks, "gates_end": b.gates.size(), "end_gold": b.gold, "spent": spent_total, "mix": mix,
		"picks": picks, "offered": _names(offered),
		"boss_min": boss_min if boss_seen else -1, "boss_steps": boss_steps,
		"battle_hash": JSON.stringify(b.to_data()).hash(), "run_hash": JSON.stringify(session.to_data()).hash(),
		"restores": restores, "offers_equal": offers_equal,
	}
	if bool(opts.get("snapshots", false)):
		out["snapshots"] = snapshots
	if bool(opts.get("draft_snapshots", false)):
		out["draft_snaps"] = draft_snaps
	return out


## Saves the session and its battle to JSON text and loads them again: the real path of a saved game.
## {} when anything refuses to load.
static func _roundtrip(game: GameData, session: RunSession) -> Dictionary:
	var text: String = JSON.stringify({"battle": session.battle.to_data(), "run": session.to_data()})
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var battle: Battle = Battle.from_data(parsed["battle"], game.catalog)
	if battle == null:
		return {}
	var again: RunSession = RunSession.from_data(parsed["run"], battle, game.run)
	if again == null:
		return {}
	return {"session": again}


static func _tier_sum(b: Battle) -> int:
	var total: int = 0
	for tower: TowerState in b.towers:
		total += tower.tier
	return total


static func _names(lists: Array) -> Array:
	var out: Array = []
	for list: Array in lists:
		var row: Array = []
		for id: StringName in list:
			row.append(String(id))
		out.append(row)
	return out
