# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## The balance bot: a strategy (the player's choices), a seeded generator and mutator for
## strategies, and a player that plays one on a Battle through the public API only
## (docs/ARCHITECTURE.md 3.3). Battles have no randomness, so a strategy and a level give one
## result. All the randomness is in making strategies, and every generator is seeded.
##
## A strategy is a Dictionary:
##   "towers": [{"cell": Vector2i, "type": StringName, "depth": 0 to 2, "spec": 0 or 1, "aim": int}]
##   "seq":    [tower index, ...]  the k-th time an index shows up is that tower's k-th purchase:
##             1 build, 2 upgrade to tier 2, 3 upgrade to tier 3 (its spec). Any order of the
##             multiset is a valid strategy, which keeps mutation simple.
##   "gate":   Vector2i, or NO_CELL for none (placed before wave 1, never moved)
##   "early":  {"on": bool, "from": waves started before calling, "live": call when at most this
##             many creatures are on the map, "max": most calls}
##   "wave_buy": bool, buy in the order of "seq" during waves as gold comes in
## The player buys strictly in the order of "seq", waiting when the next item costs too much.

const NO_CELL: Vector2i = Vector2i(-1, -1)
## 60 minutes of wave time at 1x: far past any level. A run that reaches it is reported as stuck.
const TICK_CAP: int = 72000
const BUILD_SECONDS: int = 15
const STYLES: Array[StringName] = [&"casual", &"typical", &"skilled"]
const LIVE_CHOICES: Array[int] = [0, 3, 8, 15, 40, 999]


## Level facts the generator needs, worked out once.
static func context(game: GameData, level_id: StringName) -> Dictionary:
	var level: LevelData = game.levels[level_id]
	var map: RoadMap = RoadMap.new(level)
	var road: Array[Vector2i] = []
	for r: int in level.rows:
		for c: int in Sim.MAP_COLUMNS:
			if level.is_road(Vector2i(c, r)):
				road.append(Vector2i(c, r))
	# How many road cells a tier 1 Sling Post at each spot reaches: a rough "good spot" weight.
	var reach: int = game.catalog.tower(&"sling_post").stats(1, -1).reach
	var weights: Array[int] = []
	for spot: Vector2i in level.spots:
		var seen: int = 0
		for cell: Vector2i in road:
			var dx: int = (cell.x - spot.x) * 100
			var dy: int = (cell.y - spot.y) * 100
			if dx * dx + dy * dy <= reach * reach:
				seen += 1
		weights.append(maxi(seen, 1))
	var gate_options: Array[Vector2i] = []
	for socket: Vector2i in level.sockets:
		var shut: Array[Vector2i] = [socket]
		if not map.seals(shut):
			gate_options.append(socket)
	var boss: bool = false
	for wave: WaveData in level.waves:
		for group: WaveGroup in wave.groups:
			if game.catalog.enemy(group.enemy).boss:
				boss = true
	return {"game": game, "level": level, "catalog": game.catalog, "id": level_id,
		"weights": weights, "gate_options": gate_options, "boss": boss}


# Generating strategies.

## A random strategy in one of the three styles. `allowed` is the towers it may use.
##   casual:  every spot, no upgrades, a gate or none, no early calls, default targeting.
##   typical: most spots, some upgrades, a gate or none, no early calls.
##   skilled: any number of spots, any upgrades, targeting, early calls.
static func random_strategy(ctx: Dictionary, rng: RandomNumberGenerator, style: StringName, allowed: Array[StringName]) -> Dictionary:
	if style == &"guided":
		return _guided_strategy(ctx, rng, allowed)
	var level: LevelData = ctx["level"]
	var spots: Array[Vector2i] = _spot_order(ctx, rng)
	var count: int = spots.size()
	if style == &"typical":
		count = rng.randi_range(maxi(1, spots.size() * 6 / 10), spots.size())
	elif style == &"skilled":
		count = rng.randi_range(1, spots.size())
	# Per strategy tastes: how much of each tower, how deep to upgrade, which tier 3 path.
	var type_weight: Array[float] = []
	for i: int in allowed.size():
		type_weight.append(rng.randf())
	if rng.randf() < 0.25:
		var only: int = rng.randi_range(0, allowed.size() - 1)
		for i: int in allowed.size():
			type_weight[i] = 1.0 if i == only else 0.0
	var depth_weight: Array[float] = [0.3, 0.5, 0.2]
	if style == &"casual":
		depth_weight = [1.0, 0.0, 0.0]
	elif style == &"skilled":
		depth_weight = [rng.randf(), rng.randf(), rng.randf()]
	var spec_bias: Dictionary = {}
	for type: StringName in allowed:
		spec_bias[type] = rng.randf()
	var towers: Array = []
	var depths: Array[int] = []
	for i: int in count:
		var type: StringName = allowed[_pick(rng, type_weight)]
		var depth: int = _pick(rng, depth_weight)
		var spec: int = 0 if rng.randf() < float(spec_bias[type]) else 1
		var aim: int = TowerState.Aim.FIRST
		if style != &"casual" and rng.randf() < (0.15 if style == &"typical" else 0.4):
			aim = rng.randi_range(0, 2)
		towers.append({"cell": spots[i], "type": type, "depth": depth, "spec": spec, "aim": aim})
		depths.append(depth)
	# A random order of the purchases. `breadth` is how likely the next move is a new tower.
	var breadth: float = 1.0 if style == &"casual" else rng.randf()
	var seq: Array = []
	var done: Array[int] = []
	done.resize(count)
	done.fill(0)
	var next_new: int = 0
	while true:
		var open: Array[int] = []
		for i: int in next_new:
			if done[i] <= depths[i]:
				open.append(i)
		var can_new: bool = next_new < count
		if not can_new and open.is_empty():
			break
		if can_new and (open.is_empty() or rng.randf() < breadth):
			seq.append(next_new)
			done[next_new] = 1
			next_new += 1
		else:
			var pick: int = open[rng.randi_range(0, open.size() - 1)]
			seq.append(pick)
			done[pick] += 1
	var gate: Vector2i = NO_CELL
	var options: Array[Vector2i] = ctx["gate_options"]
	if level.gates > 0 and not options.is_empty():
		var none_chance: float = 0.7 if style == &"casual" else (0.15 if style == &"typical" else 0.25)
		if rng.randf() >= none_chance:
			gate = options[rng.randi_range(0, options.size() - 1)]
	var early: Dictionary = {"on": false, "from": 1, "live": 0, "max": 99}
	if style == &"skilled" and rng.randf() < 0.4:
		early = {"on": true, "from": rng.randi_range(1, 4), "live": LIVE_CHOICES[rng.randi_range(0, LIVE_CHOICES.size() - 1)], "max": 99}
	return {"towers": towers, "seq": seq, "gate": gate, "early": early, "wave_buy": rng.randf() < 0.7}


## The guided style: a player who read the hint. Every spot gets a tower, both kinds are used, every
## tower goes to tier 2, builds come first and upgrades after. Where each kind goes and where the
## gate goes (or none) is random, so this is a floor for a thoughtful player, not a ceiling.
static func _guided_strategy(ctx: Dictionary, rng: RandomNumberGenerator, allowed: Array[StringName]) -> Dictionary:
	var level: LevelData = ctx["level"]
	var spots: Array[Vector2i] = []
	spots.append_array(level.spots)
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var kinds: Array[int] = []
	for i: int in spots.size():
		kinds.append(rng.randi_range(0, allowed.size() - 1))
	# Both kinds are used at least once, when the level offers two.
	for k: int in allowed.size():
		if not kinds.has(k):
			kinds[rng.randi_range(0, spots.size() - 1)] = k
	var towers: Array = []
	var seq: Array = []
	for i: int in spots.size():
		towers.append({"cell": spots[i], "type": allowed[kinds[i]], "depth": 1, "spec": 0, "aim": TowerState.Aim.FIRST})
		seq.append(i)
	for i: int in spots.size():
		seq.append(i)
	var gate: Vector2i = NO_CELL
	var options: Array[Vector2i] = ctx["gate_options"]
	if level.gates > 0 and not options.is_empty() and rng.randf() < 0.5:
		gate = options[rng.randi_range(0, options.size() - 1)]
	return {"towers": towers, "seq": seq, "gate": gate, "early": {"on": false, "from": 1, "live": 0, "max": 99}, "wave_buy": false}


## Spots in a random order, half the time weighted toward spots that see more road.
static func _spot_order(ctx: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var level: LevelData = ctx["level"]
	var weights: Array[int] = ctx["weights"]
	var weighted: bool = rng.randf() < 0.5
	var keyed: Array = []
	for i: int in level.spots.size():
		var u: float = maxf(rng.randf(), 0.000001)
		var w: float = float(weights[i]) if weighted else 1.0
		keyed.append([-log(u) / w, i])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[Vector2i] = []
	for item: Array in keyed:
		out.append(level.spots[int(item[1])])
	return out


## Index of a random pick by weight. All zero weights give index 0.
static func _pick(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return 0
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1


# Mutating strategies.

## A changed copy: one to three small edits, all keeping the strategy valid.
static func mutate(ctx: Dictionary, strat: Dictionary, rng: RandomNumberGenerator, allowed: Array[StringName]) -> Dictionary:
	var out: Dictionary = strat.duplicate(true)
	var edits: int = rng.randi_range(1, 3)
	for e: int in edits:
		_edit(ctx, out, rng, allowed)
	return out


static func _edit(ctx: Dictionary, s: Dictionary, rng: RandomNumberGenerator, allowed: Array[StringName]) -> void:
	var level: LevelData = ctx["level"]
	var towers: Array = s["towers"]
	var seq: Array = s["seq"]
	var kind: int = rng.randi_range(0, 13)
	match kind:
		0, 1:                                               # swap two purchases
			if seq.size() >= 2:
				var a: int = rng.randi_range(0, seq.size() - 1)
				var b: int = rng.randi_range(0, seq.size() - 1)
				var tmp: int = seq[a]
				seq[a] = seq[b]
				seq[b] = tmp
		2:                                                  # move one purchase
			if seq.size() >= 2:
				var from: int = rng.randi_range(0, seq.size() - 1)
				var item: int = seq[from]
				seq.remove_at(from)
				seq.insert(rng.randi_range(0, seq.size()), item)
		3:                                                  # change a tower's type
			if not towers.is_empty() and allowed.size() > 1:
				var t: Dictionary = towers[rng.randi_range(0, towers.size() - 1)]
				t["type"] = allowed[rng.randi_range(0, allowed.size() - 1)]
		4:                                                  # one more upgrade
			if not towers.is_empty():
				var i: int = rng.randi_range(0, towers.size() - 1)
				var t: Dictionary = towers[i]
				if int(t["depth"]) < 2:
					t["depth"] = int(t["depth"]) + 1
					seq.insert(rng.randi_range(_last_index(seq, i) + 1, seq.size()), i)
		5:                                                  # one upgrade fewer
			if not towers.is_empty():
				var i: int = rng.randi_range(0, towers.size() - 1)
				var t: Dictionary = towers[i]
				if int(t["depth"]) > 0:
					t["depth"] = int(t["depth"]) - 1
					seq.remove_at(_last_index(seq, i))
		6:                                                  # add a tower on a free spot
			var free: Array[Vector2i] = []
			for spot: Vector2i in level.spots:
				if _tower_index(towers, spot) < 0:
					free.append(spot)
			if not free.is_empty():
				towers.append({"cell": free[rng.randi_range(0, free.size() - 1)], "type": allowed[rng.randi_range(0, allowed.size() - 1)],
					"depth": 0, "spec": rng.randi_range(0, 1), "aim": TowerState.Aim.FIRST})
				seq.insert(rng.randi_range(0, seq.size()), towers.size() - 1)
		7:                                                  # remove a tower
			if towers.size() > 1:
				var i: int = rng.randi_range(0, towers.size() - 1)
				towers.remove_at(i)
				var kept: Array = []
				for item: int in seq:
					if item == i:
						continue
					kept.append(item - 1 if item > i else item)
				seq.clear()
				seq.append_array(kept)
		8:                                                  # move a tower to another spot
			var free2: Array[Vector2i] = []
			for spot: Vector2i in level.spots:
				if _tower_index(towers, spot) < 0:
					free2.append(spot)
			if not towers.is_empty() and not free2.is_empty():
				var t: Dictionary = towers[rng.randi_range(0, towers.size() - 1)]
				t["cell"] = free2[rng.randi_range(0, free2.size() - 1)]
		9:                                                  # swap the spots of two towers
			if towers.size() >= 2:
				var a: int = rng.randi_range(0, towers.size() - 1)
				var b: int = rng.randi_range(0, towers.size() - 1)
				var cell: Vector2i = towers[a]["cell"]
				towers[a]["cell"] = towers[b]["cell"]
				towers[b]["cell"] = cell
		10:                                                 # flip a tier 3 path
			if not towers.is_empty():
				var t: Dictionary = towers[rng.randi_range(0, towers.size() - 1)]
				t["spec"] = 1 - int(t["spec"])
		11:                                                 # change a targeting mode
			if not towers.is_empty():
				var t: Dictionary = towers[rng.randi_range(0, towers.size() - 1)]
				t["aim"] = rng.randi_range(0, 2) if rng.randf() < 0.5 else TowerState.Aim.FIRST
		12:                                                 # change the gate
			var options: Array[Vector2i] = ctx["gate_options"]
			if level.gates > 0 and not options.is_empty():
				s["gate"] = NO_CELL if rng.randf() < 0.2 else options[rng.randi_range(0, options.size() - 1)]
		13:                                                 # change the early call habit or when to buy
			if rng.randf() < 0.3:
				s["wave_buy"] = not bool(s["wave_buy"])
			else:
				var early: Dictionary = s["early"]
				var roll: float = rng.randf()
				if roll < 0.25:
					early["on"] = not bool(early["on"])
				elif roll < 0.5:
					early["from"] = rng.randi_range(1, 6)
				else:
					early["live"] = LIVE_CHOICES[rng.randi_range(0, LIVE_CHOICES.size() - 1)]


static func _last_index(seq: Array, tower: int) -> int:
	var at: int = -1
	for i: int in seq.size():
		if int(seq[i]) == tower:
			at = i
	return at


static func _tower_index(towers: Array, cell: Vector2i) -> int:
	for i: int in towers.size():
		if towers[i]["cell"] == cell:
			return i
	return -1


# Playing a strategy.

## Plays one battle to the end. Returns:
##   won, stars (bits), lives, cleared (waves), ticks, peak (most creatures on the map at once),
##   early (calls made), stuck (hit TICK_CAP), towers, max_tier, kinds (tower ids built),
##   gold_at (gold when each wave started), lives_at (lives when each wave started),
##   spent_at (gold put into towers before each wave started), wave_ticks (ticks each wave was
##   running), boss_hp (the lowest boss health seen, 0 when there is no boss or it was never seen),
##   boss_steps (the fewest road steps the boss had left to the base when last sampled, -1 for no boss).
## With timing, also step_us and step_live: the time of each tick and the creatures on the map.
## With restore_at, the battle is saved and loaded again at that tick (a mid-wave resume).
static func play(ctx: Dictionary, strat: Dictionary, relaxed: bool, timing: bool = false, restore_at: int = -1) -> Dictionary:
	var level: LevelData = ctx["level"]
	var b: Battle = Battle.create(level, ctx["catalog"], relaxed, [])
	b.record_events = false
	var gate: Vector2i = strat["gate"]
	if gate != NO_CELL and level.gates > 0:
		b.place_gate(gate)
	var seq: Array = strat["seq"]
	var towers: Array = strat["towers"]
	var steps: Array[int] = []
	steps.resize(towers.size())
	steps.fill(0)
	var cursor: Array[int] = [0]
	var early: Dictionary = strat["early"]
	var early_on: bool = bool(early["on"])
	var early_from: int = int(early["from"])
	var early_live: int = int(early["live"])
	var early_max: int = int(early["max"])
	var wave_buy: bool = bool(strat["wave_buy"])
	var calls: int = 0
	var peak: int = 0
	var gold_at: Array[int] = []
	var lives_at: Array[int] = []
	var spent_at: Array[int] = []
	var wave_ticks: Array[int] = []
	var step_us: PackedInt32Array = PackedInt32Array()
	var step_live: PackedInt32Array = PackedInt32Array()
	var spent: Array[int] = [0]
	var boss_hp: int = 0
	var boss_steps: int = -1
	var boss_level: bool = ctx.get("boss", false)
	var boss_dist: PackedInt32Array = b.map.distances(b.closed_cells())
	var wave_count: int = b.wave_count()
	while b.phase == Battle.Phase.BUILD and b.tick < TICK_CAP:
		_buy(b, seq, towers, steps, cursor, spent)
		gold_at.append(b.gold)
		lives_at.append(b.lives)
		spent_at.append(spent[0])
		var started_at: int = b.tick
		if b.start_next_wave() != Battle.DONE:
			break
		wave_ticks.append(0)
		var wave_index: int = wave_ticks.size() - 1
		var first_tick: int = started_at
		while b.phase == Battle.Phase.WAVE and b.tick < TICK_CAP:
			if wave_buy and cursor[0] < seq.size() and b.tick % 4 == 0:
				_buy(b, seq, towers, steps, cursor, spent)
			if early_on and b.waves_started < wave_count and b.waves_started >= early_from \
					and calls < early_max and b.enemies.size() <= early_live and b.tick % 2 == 0:
				var before_gold: int = b.gold
				if b.start_next_wave() == Battle.DONE:
					calls += 1
					gold_at.append(before_gold)
					lives_at.append(b.lives)
					spent_at.append(spent[0])
					wave_ticks.append(0)
					wave_index = wave_ticks.size() - 1
					wave_ticks[wave_index - 1] = b.tick - first_tick
					first_tick = b.tick
			if b.tick == restore_at:
				# A saved game loaded again: the rest of the battle must play the same.
				var copy: Battle = Battle.from_data(b.to_data(), ctx["catalog"])
				if copy == null:
					return {"restore_failed": true, "won": false, "stars": 0, "lives": 0, "cleared": 0, "ticks": b.tick, "digest": 0, "stuck": true}
				b = copy
				b.record_events = false
			if timing:
				var t0: int = Time.get_ticks_usec()
				b.step()
				step_us.append(Time.get_ticks_usec() - t0)
				step_live.append(b.enemies.size())
			else:
				b.step()
			if b.enemies.size() > peak:
				peak = b.enemies.size()
			if boss_level and b.tick % 5 == 0:
				for enemy: EnemyState in b.enemies:
					if ctx["catalog"].enemy(enemy.type).boss:
						boss_hp = enemy.health if boss_hp == 0 else mini(boss_hp, enemy.health)
						var steps_left: int = boss_dist[(enemy.pos.y / Sim.UNIT) * Sim.MAP_COLUMNS + enemy.pos.x / Sim.UNIT]
						boss_steps = steps_left if boss_steps < 0 else mini(boss_steps, steps_left)
		wave_ticks[wave_index] = b.tick - first_tick
	var out: Dictionary = b.result()
	out["lives"] = out["lives_left"]
	out["cleared"] = out["waves_cleared"]
	var kinds: Array[StringName] = []
	var max_tier: int = 0
	# What stands at the end: towers by id, and tier 3 paths by id (not what the strategy planned).
	var built: Dictionary = {}
	for tower: TowerState in b.towers:
		if not kinds.has(tower.type):
			kinds.append(tower.type)
		max_tier = maxi(max_tier, tower.tier)
		var key: String = String(tower.type)
		built[key] = int(built.get(key, 0)) + 1
		if tower.tier == 3:
			var path: String = String(ctx["catalog"].tower(tower.type).specs[tower.spec])
			built[path] = int(built.get(path, 0)) + 1
	out["built"] = built
	out["ticks"] = b.tick
	out["peak"] = peak
	out["early"] = calls
	out["stuck"] = b.phase == Battle.Phase.WAVE or b.phase == Battle.Phase.BUILD
	out["towers"] = b.towers.size()
	out["max_tier"] = max_tier
	out["kinds"] = kinds
	out["gold_at"] = gold_at
	out["lives_at"] = lives_at
	out["spent_at"] = spent_at
	out["wave_ticks"] = wave_ticks
	out["end_gold"] = b.gold
	out["boss_hp"] = boss_hp
	out["boss_steps"] = boss_steps
	out["digest"] = JSON.stringify(b.to_data()).hash()
	if timing:
		out["step_us"] = step_us
		out["step_live"] = step_live
	return out


## Buys in the order of the strategy while gold lasts. A refusal other than too_poor skips the item.
static func _buy(b: Battle, seq: Array, towers: Array, steps: Array[int], cursor: Array[int], spent: Array[int]) -> void:
	while cursor[0] < seq.size():
		var index: int = seq[cursor[0]]
		var t: Dictionary = towers[index]
		var step: int = steps[index]
		var cell: Vector2i = t["cell"]
		var before: int = b.gold
		var refusal: StringName
		if step == 0:
			refusal = b.place_tower(cell, t["type"])
		elif step == 1:
			refusal = b.upgrade_tower(cell, -1)
		else:
			refusal = b.upgrade_tower(cell, int(t["spec"]))
		if refusal == &"too_poor":
			return
		steps[index] = step + 1
		cursor[0] += 1
		if refusal == Battle.DONE:
			spent[0] += before - b.gold
			if step == 0 and int(t["aim"]) != TowerState.Aim.FIRST:
				b.set_aim(cell, int(t["aim"]) as TowerState.Aim)


# Describing and saving strategies.

## The strategy as plain JSON values.
static func to_data(strat: Dictionary) -> Dictionary:
	var towers: Array = []
	for t: Dictionary in strat["towers"]:
		var cell: Vector2i = t["cell"]
		towers.append({"cell": [cell.x, cell.y], "type": String(t["type"]), "depth": t["depth"], "spec": t["spec"], "aim": t["aim"]})
	var gate: Vector2i = strat["gate"]
	return {"towers": towers, "seq": strat["seq"].duplicate(), "gate": [gate.x, gate.y],
		"early": strat["early"].duplicate(), "wave_buy": strat["wave_buy"]}


static func from_data(data: Dictionary) -> Dictionary:
	var towers: Array = []
	for item: Dictionary in data["towers"]:
		var cell: Array = item["cell"]
		towers.append({"cell": Vector2i(int(cell[0]), int(cell[1])), "type": StringName(item["type"]),
			"depth": int(item["depth"]), "spec": int(item["spec"]), "aim": int(item["aim"])})
	var seq: Array = []
	for item: Variant in data["seq"]:
		seq.append(int(item))
	var gate: Array = data["gate"]
	var early_in: Dictionary = data["early"]
	var early: Dictionary = {"on": bool(early_in["on"]), "from": int(early_in["from"]), "live": int(early_in["live"]), "max": int(early_in["max"])}
	return {"towers": towers, "seq": seq, "gate": Vector2i(int(gate[0]), int(gate[1])), "early": early, "wave_buy": bool(data["wave_buy"])}


## A key that is the same for two strategies that play the same.
static func signature(strat: Dictionary) -> String:
	return JSON.stringify(to_data(strat))


## What a strategy builds at the end: tower ids and tier 3 paths, counted.
static func inventory(ctx: Dictionary, strat: Dictionary) -> Dictionary:
	var catalog: Catalog = ctx["catalog"]
	var out: Dictionary = {}
	for t: Dictionary in strat["towers"]:
		var key: String = String(t["type"])
		out[key] = int(out.get(key, 0)) + 1
		if int(t["depth"]) == 2:
			var path: String = String(catalog.tower(t["type"]).specs[int(t["spec"])])
			out[path] = int(out.get(path, 0)) + 1
	return out


## Plain text for a report: a map with the spots lettered, then the buying order.
static func describe(ctx: Dictionary, strat: Dictionary) -> String:
	var level: LevelData = ctx["level"]
	var catalog: Catalog = ctx["catalog"]
	var letters: String = "ABCDEFGHIJKLMNOPQRSTUVWX"
	var lines: PackedStringArray = PackedStringArray()
	var gate: Vector2i = strat["gate"]
	for r: int in level.rows:
		var row: String = ""
		for c: int in Sim.MAP_COLUMNS:
			var cell: Vector2i = Vector2i(c, r)
			var ch: String = level.grid[r][c]
			if level.kind_at(cell) == LevelData.Kind.SPOT:
				ch = letters[level.spots.find(cell)]
			elif cell == gate:
				ch = "X"
			row += ch
		lines.append(row)
	var text: String = "\n".join(lines) + "\n"
	text += "Gate: %s\n" % ("none" if gate == NO_CELL else "socket (%d,%d) shown as X" % [gate.x, gate.y])
	var steps: Array[int] = []
	steps.resize(strat["towers"].size())
	steps.fill(0)
	var n: int = 0
	for index: int in strat["seq"]:
		var t: Dictionary = strat["towers"][index]
		var spot: String = letters[level.spots.find(t["cell"])]
		var type: TowerType = catalog.tower(t["type"])
		var step: int = steps[index]
		steps[index] += 1
		n += 1
		var what: String = "build %s" % type.name
		if step == 1:
			what = "upgrade %s to tier 2" % type.name
		elif step == 2:
			what = "upgrade %s to %s" % [type.name, type.spec_name(int(t["spec"]))]
		var aim: String = ""
		if step == 0 and int(t["aim"]) != TowerState.Aim.FIRST and type.kind == &"attack":
			aim = ", aim %s" % ["first", "last", "strong"][int(t["aim"])]
		text += "%d. spot %s: %s%s\n" % [n, spot, what, aim]
	var early: Dictionary = strat["early"]
	if bool(early["on"]):
		text += "Early calls: from wave %d on, when at most %d creatures are on the map.\n" % [int(early["from"]) + 1, int(early["live"])]
	else:
		text += "Early calls: none.\n"
	text += "Buys %s.\n" % ("during waves as gold comes in, and in build phases" if bool(strat["wave_buy"]) else "only in build phases")
	return text


## Fitness for the search: a win beats everything, then stars, then lives. A loss scores by waves cleared.
static func fitness(res: Dictionary) -> int:
	var stars: int = int(res["stars"])
	if bool(res["won"]):
		return 10000 + (1000 if (stars & 2) != 0 else 0) + (3000 if (stars & 4) != 0 else 0) + int(res["lives"])
	return int(res["cleared"]) * 100 + int(res["lives"])
