# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Battle
extends RefCounted
## One map being defended (docs/ARCHITECTURE.md 3.1). Every rule and number comes
## from docs/design/RULES.md; section numbers in comments are RULES sections.
##
## Phase 5 builds region 1: attacking towers (the Sling Post, the Pumpkin Catapult
## and both of their paths; the same code serves any attacking tower), walkers,
## flyers, bubbles, slows and boss summons. Bells, Bakeries, heals, splits, gate
## breakers, boss speed ups and health releases, and every Twist and card effect
## come in phase 7, each in the place marked "phase 7".

enum Phase { BUILD, WAVE, WON, LOST }
const FORMAT: int = 1
const DONE: StringName = &"done"                       # a command was carried out

const PHASE_NAMES: PackedStringArray = ["build", "wave", "won", "lost"]
const AIM_NAMES: PackedStringArray = ["first", "last", "strong"]
const MAX_ENEMIES: int = 4000
const MAX_RELEASES: int = 1000
const ID_CEILING: int = 2147483648                     # 2^31
const BIG: int = 1000000000
const SAVE_KEYS: PackedStringArray = [
	"format", "level", "relaxed", "effects", "risk", "tick", "phase", "waves_started",
	"running", "wave_start", "gold", "lives", "start_lives", "gates_in_hand", "gates",
	"towers", "enemies", "releases", "next_id", "record",
]
const RECORD_KEYS: PackedStringArray = [
	"early_calls", "max_towers", "built", "max_tier", "max_gates_at_start", "gates_whole",
	"waves_cleared",
]


## A batch of creatures being released at one spot (6.2). Internal.
class Release extends RefCounted:
	var enemy: StringName = &""
	var wave: int = 0
	var left: int = 0                                  # creatures still to come
	var next: int = 0                                  # the tick the next one appears
	var gap: int = 1                                   # ticks between two
	var from_cell: Vector2i = Vector2i.ZERO            # a released walker's step
	var to_cell: Vector2i = Vector2i.ZERO
	var progress: int = 0
	var pos: Vector2i = Vector2i.ZERO                  # a released flyer's start


# Fixed for the whole battle. Read only.
var level: LevelData = null
var catalog: Catalog = null
var map: RoadMap = null
var relaxed: bool = false

# State. Read only outside src/sim/.
var tick: int = 0
var phase: Phase = Phase.BUILD
var waves_started: int = 0                             # the next wave to start has this index
var running: Array[int] = []                           # indexes of the waves on the map, oldest first
var gold: int = 0
var lives: int = 0
var start_lives: int = 0
var gates_in_hand: int = 0
var gates: Array[GateState] = []                       # cell order
var towers: Array[TowerState] = []                     # cell order
var enemies: Array[EnemyState] = []                    # id order
var risk_waiting: Array[Dictionary] = []               # phase 7; always [] in phase 5
var record_events: bool = true                         # bots set false for speed

var _wave_start: Array[int] = []                       # the tick each started wave began
var _releases: Array[Release] = []                     # in the order they began
var _summoners: Array[EnemyState] = []                 # creatures with a summon, in id order
var _next_id: int = 0
var _events: Array[Dictionary] = []
var _dist: PackedInt32Array = PackedInt32Array()       # walker distances for the closed set now
var _free_dist: PackedInt32Array = PackedInt32Array()  # distances with no gates (the breaker route)
# What the star rules need (2.7).
var _early_calls: int = 0
var _max_towers: int = 0
var _built: Array[StringName] = []
var _max_tier: int = 0
var _max_gates_at_start: int = 0
var _gates_whole: bool = true
var _waves_cleared: int = 0
# Scratch for one tick: walkers bucketed by cell, and the flyers.
var _head: PackedInt32Array = PackedInt32Array()
var _link: PackedInt32Array = PackedInt32Array()
var _flyer_list: PackedInt32Array = PackedInt32Array()
var _removed: bool = false


static func create(level_data: LevelData, stats: Catalog, is_relaxed: bool, twist_effects: Array[Dictionary]) -> Battle:
	if level_data == null or stats == null or stats.rules == null:
		return null
	# Twist effects come in phase 7. Until then a Twist cannot be played.
	if not twist_effects.is_empty():
		return null
	var battle: Battle = Battle.new()
	battle._setup(level_data, stats)
	battle.relaxed = is_relaxed
	var rules: GameRules = stats.rules
	battle.start_lives = rules.start_lives
	battle.gold = level_data.start_gold
	if is_relaxed:
		# 11: Relaxed lives, and gold rounded up to a multiple of 10.
		battle.start_lives = rules.start_lives * rules.relaxed_lives_pct / 100
		battle.gold = (level_data.start_gold * rules.relaxed_gold_pct + 999) / 1000 * 10
	battle.lives = battle.start_lives
	battle.gates_in_hand = level_data.gates
	battle._refresh_dist()
	return battle


func _setup(level_data: LevelData, stats: Catalog) -> void:
	level = level_data
	catalog = stats
	map = RoadMap.new(level_data)
	_free_dist = map.distances([])
	_head.resize(map.size())


## One tick (8.1). Does nothing unless phase is WAVE.
func step() -> void:
	if phase != Phase.WAVE:
		return
	_spawn_step()
	_timer_step()
	# Step 3, Bells, comes in phase 7.
	_move_step()
	if phase == Phase.LOST:
		tick += 1
		return
	_tower_step()
	_defeat_step()
	_wave_step()
	tick += 1


## The events since the last call, oldest first.
func take_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events
	_events = []
	return out


# Player commands.

func place_tower(cell: Vector2i, type: StringName) -> StringName:
	if _over():
		return &"over"
	if level.kind_at(cell) != LevelData.Kind.SPOT:
		return &"not_a_spot"
	if tower_at(cell) != null:
		return &"occupied"
	if not _offered(type):
		return &"not_offered"
	var price: int = catalog.tower(type).stats(1, -1).cost
	if gold < price:
		return &"too_poor"
	gold -= price
	var tower: TowerState = TowerState.new()
	tower.cell = cell
	tower.type = type
	_pay(tower, price)
	var at: int = towers.size()
	for i: int in towers.size():
		if Sim.cell_before(cell, towers[i].cell):
			at = i
			break
	towers.insert(at, tower)
	_refresh_reach(tower)
	if not _built.has(type):
		_built.append(type)
	_max_towers = maxi(_max_towers, towers.size())
	_max_tier = maxi(_max_tier, 1)
	_emit({"kind": &"built", "cell": cell, "tower": type, "tier": 1, "spec": -1, "gold": price})
	return DONE


## spec 0 or 1 only from tier 2 to 3.
func upgrade_tower(cell: Vector2i, spec: int = -1) -> StringName:
	if _over():
		return &"over"
	var tower: TowerState = tower_at(cell)
	if tower == null:
		return &"no_tower"
	var refusal: StringName = _upgrade_refusal(tower, spec)
	if refusal != &"":
		return refusal
	var price: int = _stats_at(tower.type, tower.tier + 1, spec).cost
	gold -= price
	_pay(tower, price)
	tower.tier += 1
	tower.spec = spec
	# 5.2: the timer keeps running but never stays above the new reload.
	tower.reload = mini(tower.reload, _stats(tower).reload_ms * 100)
	_refresh_reach(tower)
	_max_tier = maxi(_max_tier, tower.tier)
	_emit({"kind": &"upgraded", "cell": cell, "tower": tower.type, "tier": tower.tier, "spec": tower.spec, "gold": price})
	return DONE


func sell_tower(cell: Vector2i) -> StringName:
	if _over():
		return &"over"
	var tower: TowerState = tower_at(cell)
	if tower == null:
		return &"no_tower"
	# A Twist's no_selling comes in phase 7.
	var refund: int = sell_value(cell)
	gold += refund
	towers.erase(tower)
	_emit({"kind": &"sold", "cell": cell, "tower": tower.type, "tier": tower.tier, "spec": tower.spec, "gold": refund})
	return DONE


func set_aim(cell: Vector2i, aim: TowerState.Aim) -> StringName:
	if _over():
		return &"over"
	var tower: TowerState = tower_at(cell)
	if tower == null:
		return &"no_tower"
	if catalog.tower(tower.type).kind != &"attack":
		return &"no_aim"
	if aim < 0 or aim >= AIM_NAMES.size():
		return &"bad_aim"
	tower.aim = aim
	return DONE


func place_gate(cell: Vector2i) -> StringName:
	var refusal: StringName = _gate_refusal()
	if refusal != &"":
		return refusal
	if not level.sockets.has(cell):
		return &"not_a_socket"
	if _gate_at(cell) != null:
		return &"has_gate"
	if gates_in_hand <= 0:
		return &"no_gates_left"
	var closed: Array[Vector2i] = closed_cells()
	closed.append(cell)
	if map.seals(closed):
		return &"would_seal"
	gates_in_hand -= 1
	_add_gate(cell)
	_emit({"kind": &"gate_placed", "cell": cell})
	return DONE


## One step: the gate leaves its socket and closes the new one at the same moment (7.2).
func move_gate(from: Vector2i, to: Vector2i) -> StringName:
	var refusal: StringName = _gate_refusal()
	if refusal != &"":
		return refusal
	var gate: GateState = _gate_at(from)
	if gate == null:
		return &"no_gate"
	if gate.fixed:
		return &"fixed_gate"
	if not level.sockets.has(to):
		return &"not_a_socket"
	if _gate_at(to) != null:
		return &"has_gate"
	var closed: Array[Vector2i] = closed_cells()
	closed.erase(from)
	closed.append(to)
	if map.seals(closed):
		return &"would_seal"
	gates.erase(gate)
	_add_gate(to)
	_emit({"kind": &"gate_removed", "cell": from})
	_emit({"kind": &"gate_placed", "cell": to})
	return DONE


func remove_gate(cell: Vector2i) -> StringName:
	var refusal: StringName = _gate_refusal()
	if refusal != &"":
		return refusal
	var gate: GateState = _gate_at(cell)
	if gate == null:
		return &"no_gate"
	if gate.fixed:
		return &"fixed_gate"
	gates.erase(gate)
	gates_in_hand += 1
	_refresh_dist()
	_emit({"kind": &"gate_removed", "cell": cell})
	return DONE


## From BUILD: starts the next wave. In WAVE: an early call with its bonus (4.9).
func start_next_wave() -> StringName:
	var refusal: StringName = _wave_refusal()
	if refusal != &"":
		return refusal
	var early: bool = phase == Phase.WAVE
	if early:
		gold += _early_bonus()
		_early_calls += 1
	_max_gates_at_start = maxi(_max_gates_at_start, gates.size())
	if gates.size() < level.gates:
		_gates_whole = false
	# 4.6: from now on, this build phase's purchases refund at the refund percent.
	for tower: TowerState in towers:
		tower.spent_before += tower.spent_now
		tower.spent_now = 0
	var index: int = waves_started
	_wave_start.append(tick)
	waves_started += 1
	running.append(index)
	phase = Phase.WAVE
	_emit({"kind": &"wave_started", "wave": index, "early": early})
	return DONE


## A picked card (phase 7). Phase 5 battles take no effects.
func add_effects(_effects: Array[Dictionary], _risk: bool) -> StringName:
	if _over():
		return &"over"
	return &"bad_effect"


# Queries.

func tower_at(cell: Vector2i) -> TowerState:
	for tower: TowerState in towers:
		if tower.cell == cell:
			return tower
	return null


func enemy_with_id(id: int) -> EnemyState:
	var lo: int = 0
	var hi: int = enemies.size() - 1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		var found: int = enemies[mid].id
		if found == id:
			return enemies[mid]
		if found < id:
			lo = mid + 1
		else:
			hi = mid - 1
	return null


## [{"tower", "cost", "affordable", "numbers"}] for a free build spot; [] otherwise.
func build_options(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if level.kind_at(cell) != LevelData.Kind.SPOT or tower_at(cell) != null:
		return out
	for type: StringName in level.towers:
		if not _offered(type):
			continue
		var stats: TowerStats = _stats_at(type, 1, -1)
		out.append({"tower": type, "cost": stats.cost, "affordable": gold >= stats.cost, "numbers": stats.numbers()})
	return out


func tower_numbers(cell: Vector2i) -> Dictionary:
	var tower: TowerState = tower_at(cell)
	if tower == null:
		return {}
	var numbers: Dictionary = _stats(tower).numbers()
	var boost: Vector2i = _boost_for(tower)
	numbers["got_pct"] = boost.x
	numbers["got_damage"] = boost.y
	numbers["boosting"] = 0                            # Bakeries come in phase 7
	numbers["spent"] = tower.spent_now + tower.spent_before
	numbers["sell"] = sell_value(cell)
	numbers["aim"] = tower.aim
	return numbers


## One entry, or two for the step to tier 3: {"spec", "cost", "refusal", "before", "after"}.
func upgrade_options(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tower: TowerState = tower_at(cell)
	if tower == null or tower.tier >= 3:
		return out
	var specs: Array[int] = []
	if tower.tier == 1:
		specs.append(-1)
	else:
		specs.append_array([0, 1])
	var before: Dictionary = _stats(tower).numbers()
	for spec: int in specs:
		var after: TowerStats = _stats_at(tower.type, tower.tier + 1, spec)
		var refusal: StringName = &"over" if _over() else _upgrade_refusal(tower, spec)
		out.append({"spec": spec, "cost": after.cost, "refusal": refusal, "before": before, "after": after.numbers()})
	return out


## 4.6: this build phase's purchases in full, plus the refund percent of the rest, rounded down.
func sell_value(cell: Vector2i) -> int:
	var tower: TowerState = tower_at(cell)
	if tower == null:
		return 0
	return tower.spent_now + tower.spent_before * catalog.rules.refund_pct / 100


func enemy_numbers(id: int) -> Dictionary:
	var enemy: EnemyState = enemy_with_id(id)
	if enemy == null:
		return {}
	var type: EnemyType = catalog.enemy(enemy.type)
	return {
		"health": enemy.health, "max_health": enemy.max_health, "armor": enemy.armor,
		"speed": enemy.speed * (100 - enemy.slow_pct) / 100, "base_speed": enemy.speed,
		"flying": enemy.flying, "lives": enemy.lives, "bounty": enemy.bounty,
		"heal": _scaled(type.heal, enemy.wave) if type.heal > 0 else 0,
		"slow_pct": enemy.slow_pct, "slow_ms": enemy.slow_ticks * Sim.MS_PER_TICK,
		"bubble": enemy.bubble, "bubble_ms": enemy.bubble_ticks * Sim.MS_PER_TICK,
		"breaking_ms": enemy.breaking / 100,
	}


## The sockets closed to walkers right now, in cell order.
func closed_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for gate: GateState in gates:
		if not gate.broken:
			out.append(gate.cell)
	return out


## Route lines (docs/ARCHITECTURE.md 4.8), one entry per entrance.
func routes(closed: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dist: PackedInt32Array = map.distances(closed)
	for i: int in level.entrances.size():
		var fly: bool = false
		if waves_started < level.waves.size():
			for group: WaveGroup in level.waves[waves_started].groups:
				if group.entrance == i and catalog.enemy(group.enemy).flying:
					fly = true
		var no_cells: Array[Vector2i] = []
		# The breaker route and its cracks come with gate breakers in phase 7.
		out.append({"entrance": i + 1, "walk": map.route(level.entrances[i], dist),
			"break": no_cells, "cracks": no_cells.duplicate(), "fly": fly})
	return out


func seals(closed: Array[Vector2i]) -> bool:
	return map.seals(closed)


func wave_count() -> int:
	return level.waves.size()


## One row per group in spawn order, at that wave's strength (9.1).
func wave_preview(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if index < 0 or index >= level.waves.size():
		return out
	for group: WaveGroup in level.waves[index].groups:
		var type: EnemyType = catalog.enemy(group.enemy)
		out.append({
			"enemy": group.enemy, "count": group.count, "entrance": group.entrance + 1,
			"health": _scaled(type.health, index), "bounty": _scaled(type.bounty, index),
			"heal": _scaled(type.heal, index) if type.heal > 0 else 0,
		})
	return out


## {"refusal": &"" when the next wave can start, "early", "bonus"}.
func next_wave_info() -> Dictionary:
	var early: bool = phase == Phase.WAVE
	return {"refusal": _wave_refusal(), "early": early, "bonus": _early_bonus() if early else 0}


## {"won", "stars" (bits: 1, 2, 4), "lives_left", "waves_cleared"}; won and stars only once WON.
func result() -> Dictionary:
	var won: bool = phase == Phase.WON
	return {"won": won, "stars": _stars() if won else 0, "lives_left": maxi(lives, 0), "waves_cleared": _waves_cleared}


# The tick.

## Step 1: group spawns in wave data order, waves in start order, then releases (8.1).
func _spawn_step() -> void:
	for w: int in running:
		var elapsed: int = tick - _wave_start[w]
		for group: WaveGroup in level.waves[w].groups:
			var since: int = elapsed - group.at_tick
			if since < 0 or since % group.every_ticks != 0 or since / group.every_ticks >= group.count:
				continue
			var enemy: EnemyState = _new_enemy(group.enemy, w)
			var cell: Vector2i = level.entrances[group.entrance]
			if enemy.flying:
				_launch(enemy, Sim.center(cell))
			else:
				enemy.from_cell = cell
				enemy.to_cell = cell
				enemy.progress = Sim.UNIT
			_add_enemy(enemy)
	# Boss summons (6.3): a batch begins at the boss's spot now. Summoners are kept in
	# spawn order; gone ones (health 0 or less) drop out.
	if not _summoners.is_empty():
		var alive: Array[EnemyState] = []
		for boss: EnemyState in _summoners:
			if boss.health <= 0:
				continue
			alive.append(boss)
			if boss.summon_at > tick:
				continue
			var summon: Dictionary = catalog.enemy(boss.type).summon
			_begin_release(boss, summon["enemy"], summon["count"], summon["gap_ms"] / Sim.MS_PER_TICK)
			boss.summon_at += summon["every_ms"] / Sim.MS_PER_TICK
		_summoners = alive
	# Releases that are due. A begun release always finishes (6.2).
	var r: int = 0
	while r < _releases.size():
		var release: Release = _releases[r]
		if release.next > tick:
			r += 1
			continue
		var enemy: EnemyState = _new_enemy(release.enemy, release.wave)
		if enemy.flying:
			_launch(enemy, release.pos)
		else:
			enemy.from_cell = release.from_cell
			enemy.to_cell = release.to_cell
			enemy.progress = release.progress
		_add_enemy(enemy)
		release.left -= 1
		release.next += release.gap
		if release.left <= 0:
			_releases.remove_at(r)
		else:
			r += 1


func _begin_release(source: EnemyState, type: StringName, count: int, gap: int) -> void:
	var release: Release = Release.new()
	release.enemy = type
	release.wave = source.wave
	release.left = count
	release.next = tick
	release.gap = gap
	release.from_cell = source.from_cell
	release.to_cell = source.to_cell
	release.progress = source.progress
	release.pos = source.pos
	_releases.append(release)


## Step 2: bubbles, slows. Heals and break timers come in phase 7.
func _timer_step() -> void:
	for enemy: EnemyState in enemies:
		if enemy.bubble_ticks > 0:
			enemy.bubble_ticks -= 1
			if enemy.bubble_ticks == 0:
				enemy.bubble = true
		if enemy.slow_ticks > 0:
			enemy.slow_ticks -= 1
			if enemy.slow_ticks == 0:
				enemy.slow_pct = 0


## Step 4: movement. A creature at the base center is removed and costs its lives.
func _move_step() -> void:
	for enemy: EnemyState in enemies:
		enemy.prev_pos = enemy.pos
		var amount: int = enemy.speed * 10 * (100 - enemy.slow_pct) / 100
		var through: bool = false
		if enemy.flying:
			enemy.flown += amount
			if enemy.flown >= enemy.fly_length:
				enemy.flown = enemy.fly_length
				through = true
			_place(enemy)
		elif enemy.progress + amount < Sim.UNIT:
			# Inside its step: the position moves exactly `amount` along the step.
			enemy.progress += amount
			enemy.pos += (enemy.to_cell - enemy.from_cell) * amount
			continue
		else:
			through = _walk(enemy, amount)
		if not through:
			continue
		enemy.health = 0
		_removed = true
		lives -= enemy.lives
		_emit({"kind": &"leaked", "id": enemy.id, "enemy": enemy.type, "lives": enemy.lives})
		if lives <= 0:
			phase = Phase.LOST
			_compact()
			_emit({"kind": &"lost"})
			return
	_compact()


## Moves a walker along cell centers (7.3). Returns true when it reaches the base.
func _walk(enemy: EnemyState, amount: int) -> bool:
	var dist: PackedInt32Array = _free_dist if enemy.breaker else _dist
	var budget: int = amount
	while true:
		if enemy.progress >= Sim.UNIT:
			if enemy.to_cell == level.base:
				_place(enemy)
				return true
			if budget <= 0:
				break
			var next: Vector2i = map.next_step(enemy.to_cell, dist)
			if next == enemy.to_cell:
				break
			enemy.from_cell = enemy.to_cell
			enemy.to_cell = next
			enemy.progress = 0
		var room: int = Sim.UNIT - enemy.progress
		if budget < room:
			enemy.progress += budget
			break
		enemy.progress = Sim.UNIT
		budget -= room
	_place(enemy)
	return false


## Step 5: towers in spot order. Hits land at once (5.2, 8.2 to 8.5).
func _tower_step() -> void:
	_bucket()
	for tower: TowerState in towers:
		var type: TowerType = catalog.tower(tower.type)
		if type.kind != &"attack":
			continue                                   # Bells and Bakeries: phase 7
		var stats: TowerStats = _stats(tower)
		var boost: Vector2i = _boost_for(tower)
		tower.reload -= Sim.MS_PER_TICK * (100 + boost.x)
		if tower.reload > 0:
			continue
		var picks: Array[int] = _pick_targets(tower, stats)
		if picks.is_empty():
			tower.reload = 0
			continue
		tower.reload += stats.reload_ms * 100
		var ids: Array[int] = []
		var at: Array[Vector2i] = []
		for index: int in picks:
			ids.append(enemies[index].id)
			at.append(enemies[index].pos)
		_emit({"kind": &"fired", "cell": tower.cell, "tower": tower.type, "spec": tower.spec, "targets": ids, "at": at})
		for index: int in picks:
			var target: EnemyState = enemies[index]
			if target.health <= 0:
				continue                               # already defeated by this shot's splash
			if stats.splash <= 0:
				_hit(target, stats, boost.y)
				continue
			for victim: int in _splash_victims(target.pos, stats):
				_hit(enemies[victim], stats, boost.y)


## Step 6: defeats pay their bounties (4.5). Splits and boss health events: phase 7.
func _defeat_step() -> void:
	for enemy: EnemyState in enemies:
		if enemy.health > 0:
			continue
		gold += enemy.bounty
		_removed = true
		_emit({"kind": &"defeated", "id": enemy.id, "enemy": enemy.type, "pos": enemy.pos, "gold": enemy.bounty})
	_compact()


## Step 7: wave checks (4.1, 4.5, 8.1).
func _wave_step() -> void:
	var on_map: PackedInt32Array = PackedInt32Array()
	on_map.resize(level.waves.size())
	for enemy: EnemyState in enemies:
		on_map[enemy.wave] += 1
	for release: Release in _releases:
		on_map[release.wave] += 1
	for w: int in running.duplicate():
		if on_map[w] > 0 or not _spawned_all(w, tick - _wave_start[w]):
			continue
		running.erase(w)
		var bonus: int = _clear_bonus(w)
		gold += bonus
		_waves_cleared += 1
		_emit({"kind": &"wave_cleared", "wave": w, "gold": bonus})
	if not running.is_empty():
		return
	if waves_started >= level.waves.size() and lives > 0:
		phase = Phase.WON
		_emit({"kind": &"won"})
		return
	# A new build phase. Broken gates mend, closed, on their sockets (7.6).
	phase = Phase.BUILD
	for gate: GateState in gates:
		gate.broken = false
	_refresh_dist()
	_emit({"kind": &"build_started", "wave": waves_started})


# Combat.

## Buckets walkers by the cell they stand on, so a tower checks only cells in its reach.
func _bucket() -> void:
	_head.fill(-1)
	_link.resize(enemies.size())
	_flyer_list.resize(0)
	for i: int in enemies.size():
		var enemy: EnemyState = enemies[i]
		if enemy.flying:
			_flyer_list.append(i)
			continue
		var cell: int = (enemy.pos.y / Sim.UNIT) * Sim.MAP_COLUMNS + enemy.pos.x / Sim.UNIT
		_link[i] = _head[cell]
		_head[cell] = i


## Up to `targets` different creatures in reach, in the tower's aim order (8.2).
func _pick_targets(tower: TowerState, stats: TowerStats) -> Array[int]:
	var reach: int = stats.reach * 200
	var reach_sq: int = reach * reach
	var center: Vector2i = Sim.center(tower.cell)
	var found: PackedInt32Array = PackedInt32Array()
	var to_go: PackedInt32Array = PackedInt32Array()
	if stats.hits_ground:
		for cell: int in tower.near_cells:
			var i: int = _head[cell]
			while i >= 0:
				var enemy: EnemyState = enemies[i]
				var d: Vector2i = enemy.pos - center
				if enemy.health > 0 and d.x * d.x + d.y * d.y <= reach_sq:
					found.append(i)
					# _to_go() for a walker, inlined: this loop is the hottest in the sim.
					var dist: PackedInt32Array = _free_dist if enemy.breaker else _dist
					var step_to: Vector2i = enemy.to_cell
					to_go.append(dist[step_to.y * Sim.MAP_COLUMNS + step_to.x] * Sim.UNIT + Sim.UNIT - enemy.progress)
				i = _link[i]
	if stats.hits_air:
		for i: int in _flyer_list:
			if _in_range(enemies[i], center, reach_sq):
				found.append(i)
				to_go.append(_to_go(enemies[i]))
	var picks: Array[int] = []
	while picks.size() < stats.targets and not found.is_empty():
		var best: int = 0
		for k: int in range(1, found.size()):
			if _better(enemies[found[k]], to_go[k], enemies[found[best]], to_go[best], tower.aim):
				best = k
		picks.append(found[best])
		found.remove_at(best)
		to_go.remove_at(best)
	return picks


func _in_range(enemy: EnemyState, center: Vector2i, reach_sq: int) -> bool:
	if enemy.health <= 0:
		return false
	var dx: int = enemy.pos.x - center.x
	var dy: int = enemy.pos.y - center.y
	return dx * dx + dy * dy <= reach_sq


## True when a goes before b for this aim. First: nearest the base. Last: farthest.
## Strong: highest max health, ties by First. Any other tie: the lower id (8.2).
func _better(a: EnemyState, to_go_a: int, b: EnemyState, to_go_b: int, aim: TowerState.Aim) -> bool:
	if aim == TowerState.Aim.STRONG and a.max_health != b.max_health:
		return a.max_health > b.max_health
	if to_go_a != to_go_b:
		return to_go_a > to_go_b if aim == TowerState.Aim.LAST else to_go_a < to_go_b
	return a.id < b.id


## Distance to the base in sub-units, for targeting (docs/ARCHITECTURE.md 4.7).
func _to_go(enemy: EnemyState) -> int:
	if enemy.flying:
		return enemy.fly_length - enemy.flown
	var dist: PackedInt32Array = _free_dist if enemy.breaker else _dist
	return dist[map.index(enemy.to_cell)] * Sim.UNIT + (Sim.UNIT - enemy.progress)


## Every creature of a kind the tower hits, within the splash radius of the target's
## center, the target included, in id order (8.4).
func _splash_victims(at: Vector2i, stats: TowerStats) -> Array[int]:
	var radius: int = stats.splash * 200
	var radius_sq: int = radius * radius
	var victims: Array[int] = []
	if stats.hits_ground:
		var low: Vector2i = Sim.cell_of(at - Vector2i(radius, radius))
		var high: Vector2i = Sim.cell_of(at + Vector2i(radius, radius))
		for row: int in range(maxi(low.y, 0), mini(high.y, map.rows - 1) + 1):
			for column: int in range(maxi(low.x, 0), mini(high.x, Sim.MAP_COLUMNS - 1) + 1):
				var i: int = _head[row * Sim.MAP_COLUMNS + column]
				while i >= 0:
					if _in_range(enemies[i], at, radius_sq):
						victims.append(i)
					i = _link[i]
	if stats.hits_air:
		for i: int in _flyer_list:
			if _in_range(enemies[i], at, radius_sq):
				victims.append(i)
	victims.sort()
	return victims


## One hit on one creature (8.3): a bubble pops and blocks it; else armor, damage, slow.
func _hit(enemy: EnemyState, stats: TowerStats, bonus: int) -> void:
	if enemy.bubble:
		enemy.bubble = false
		enemy.bubble_ticks = catalog.rules.bubble_ms / Sim.MS_PER_TICK
		_emit({"kind": &"popped", "id": enemy.id})
		return
	var damage: int = stats.damage + bonus
	var taken: int = damage if stats.pierce else maxi(1, damage - enemy.armor)
	enemy.health -= taken
	if stats.slow_pct > 0:
		_slow(enemy, stats.slow_pct, stats.slow_ms / Sim.MS_PER_TICK)


## One slow slot per creature: a stronger slow replaces it, an equal one keeps the
## longer time, a weaker one changes nothing (8.5).
func _slow(enemy: EnemyState, pct: int, ticks: int) -> void:
	if pct > enemy.slow_pct:
		enemy.slow_pct = pct
		enemy.slow_ticks = ticks
	elif pct == enemy.slow_pct:
		enemy.slow_ticks = maxi(enemy.slow_ticks, ticks)


# Helpers.

func _over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


func _emit(event: Dictionary) -> void:
	if record_events:
		_events.append(event)


func _offered(type: StringName) -> bool:
	# A Twist's ban_tower and a run's add_tower come in phase 7.
	return level.towers.has(type) and catalog.has_tower(type)


func _pay(tower: TowerState, price: int) -> void:
	if phase == Phase.BUILD:
		tower.spent_now += price
	else:
		tower.spent_before += price


## A tower's own stats. Card effects fold in here in phase 7.
func _stats(tower: TowerState) -> TowerStats:
	return _stats_at(tower.type, tower.tier, tower.spec)


func _stats_at(type: StringName, tier: int, spec: int) -> TowerStats:
	return catalog.tower(type).stats(tier, spec)


## The best Bakery rate boost and damage bonus a tower gets (8.6). Phase 7.
func _boost_for(_tower: TowerState) -> Vector2i:
	return Vector2i.ZERO


func _upgrade_refusal(tower: TowerState, spec: int) -> StringName:
	if tower.tier >= 3:
		return &"top_tier"
	# A Twist's tier_cap comes in phase 7.
	if tower.tier == 1 and spec != -1:
		return &"bad_spec"
	if tower.tier == 2 and spec == -1:
		return &"pick_spec"
	if tower.tier == 2 and spec != 0 and spec != 1:
		return &"bad_spec"
	if gold < _stats_at(tower.type, tower.tier + 1, spec).cost:
		return &"too_poor"
	return &""


func _gate_refusal() -> StringName:
	if _over():
		return &"over"
	if phase != Phase.BUILD:
		return &"gates_locked"
	return &""


func _gate_at(cell: Vector2i) -> GateState:
	for gate: GateState in gates:
		if gate.cell == cell:
			return gate
	return null


func _add_gate(cell: Vector2i) -> void:
	var gate: GateState = GateState.new()
	gate.cell = cell
	var at: int = gates.size()
	for i: int in gates.size():
		if Sim.cell_before(cell, gates[i].cell):
			at = i
			break
	gates.insert(at, gate)
	_refresh_dist()


func _refresh_dist() -> void:
	_dist = map.distances(closed_cells())


func _wave_refusal() -> StringName:
	if _over():
		return &"over"
	if waves_started >= level.waves.size():
		return &"no_more_waves"
	if phase == Phase.WAVE:
		var newest: int = waves_started - 1
		if not _spawned_all(newest, tick - 1 - _wave_start[newest]):
			return &"still_spawning"
		if running.size() >= catalog.rules.max_waves_running:
			return &"too_many_waves"
	return &""


## True when every group of wave w has spawned by `elapsed` ticks after it began.
func _spawned_all(w: int, elapsed: int) -> bool:
	for group: WaveGroup in level.waves[w].groups:
		if group.at_tick + (group.count - 1) * group.every_ticks > elapsed:
			return false
	return true


## 4.9: the early call bonus percent of the bounties of the newest wave's creatures
## still on the map, rounded up.
func _early_bonus() -> int:
	if waves_started <= 0:
		return 0
	var newest: int = waves_started - 1
	var total: int = 0
	for enemy: EnemyState in enemies:
		if enemy.wave == newest and enemy.health > 0:
			total += enemy.bounty
	return Sim.pct_up(total, catalog.rules.early_bonus_pct)


## 4.5: (20 + 5 x wave number) x strength / 100, rounded half up.
func _clear_bonus(w: int) -> int:
	var rules: GameRules = catalog.rules
	return Sim.pct_half_up(rules.clear_bonus + rules.clear_bonus_per_wave * (w + 1), level.waves[w].strength)


## A base number at wave w's strength, rounded half up, at least 1 (6.4).
func _scaled(base_value: int, w: int) -> int:
	return maxi(1, Sim.pct_half_up(base_value, level.waves[w].strength))


func _new_enemy(type: StringName, w: int) -> EnemyState:
	var enemy: EnemyState = EnemyState.new()
	enemy.id = _next_id
	_next_id += 1
	enemy.type = type
	enemy.wave = w
	_derive(enemy)
	enemy.health = enemy.max_health
	var data: EnemyType = catalog.enemy(type)
	enemy.bubble = data.bubble
	if not data.summon.is_empty():
		enemy.summon_at = tick + int(data.summon["every_ms"]) / Sim.MS_PER_TICK
	return enemy


## Numbers worked out from the type and the wave's strength (6.4). Creature effects
## (phase 7) apply after strength.
func _derive(enemy: EnemyState) -> void:
	var data: EnemyType = catalog.enemy(enemy.type)
	enemy.max_health = _scaled(data.health, enemy.wave)
	enemy.bounty = _scaled(data.bounty, enemy.wave)
	enemy.armor = data.armor
	enemy.speed = data.speed
	enemy.lives = data.lives
	enemy.flying = data.flying
	enemy.breaker = false                              # gate breakers come in phase 7


## A flyer flies straight from `start` to the base center (6.5).
func _launch(enemy: EnemyState, start: Vector2i) -> void:
	enemy.fly_from = start
	enemy.fly_to = Sim.center(level.base)
	var d: Vector2i = enemy.fly_to - start
	enemy.fly_length = Sim.isqrt(d.x * d.x + d.y * d.y)
	enemy.flown = 0


func _add_enemy(enemy: EnemyState) -> void:
	_place(enemy)
	enemy.prev_pos = enemy.pos
	enemies.append(enemy)
	if enemy.summon_at > 0:
		_summoners.append(enemy)
	_emit({"kind": &"spawned", "id": enemy.id, "enemy": enemy.type, "pos": enemy.pos})


func _place(enemy: EnemyState) -> void:
	if enemy.flying:
		if enemy.fly_length <= 0:
			enemy.pos = enemy.fly_to
			return
		var d: Vector2i = enemy.fly_to - enemy.fly_from
		enemy.pos = enemy.fly_from + Vector2i(d.x * enemy.flown / enemy.fly_length, d.y * enemy.flown / enemy.fly_length)
		return
	var a: Vector2i = Sim.center(enemy.from_cell)
	var b: Vector2i = Sim.center(enemy.to_cell)
	enemy.pos = a + (b - a) * enemy.progress / Sim.UNIT


## Drops creatures marked gone (health 0 or less), keeping id order.
func _compact() -> void:
	if not _removed:
		return
	_removed = false
	var kept: Array[EnemyState] = []
	for enemy: EnemyState in enemies:
		if enemy.health > 0:
			kept.append(enemy)
	enemies = kept


## The road cells a walker in reach could stand on (docs/ARCHITECTURE.md 9.3).
func _refresh_reach(tower: TowerState) -> void:
	tower.near_cells = PackedInt32Array()
	var reach: int = _stats(tower).reach * 200
	var center: Vector2i = Sim.center(tower.cell)
	for row: int in map.rows:
		for column: int in Sim.MAP_COLUMNS:
			var cell: Vector2i = Vector2i(column, row)
			if not map.is_road(cell):
				continue
			var nx: int = clampi(center.x, column * Sim.UNIT, (column + 1) * Sim.UNIT)
			var ny: int = clampi(center.y, row * Sim.UNIT, (row + 1) * Sim.UNIT)
			var dx: int = nx - center.x
			var dy: int = ny - center.y
			if dx * dx + dy * dy <= reach * reach:
				tower.near_cells.append(map.index(cell))


func _stars() -> int:
	var bits: int = 1
	if relaxed:
		return bits
	if lives >= catalog.rules.star2_lives:
		bits |= 2
	if _star3_met():
		bits |= 4
	return bits


## 10.3 and docs/ARCHITECTURE.md 2.7.
func _star3_met() -> bool:
	var value: int = level.star3["value"]
	match level.star3["kind"]:
		&"no_lives_lost":
			return lives >= start_lives
		&"towers_at_most":
			return _max_towers <= value
		&"tower_ban":
			return not _built.has(level.star3["tower"])
		&"gates_at_most":
			return _max_gates_at_start <= value
		&"tier_at_most":
			return _max_tier <= value
		&"early_calls_at_least":
			return _early_calls >= value
		&"kinds_at_most":
			return _built.size() <= value
		&"gates_whole":
			return _gates_whole
	return false


# Save (docs/ARCHITECTURE.md 5.6).

func to_data() -> Dictionary:
	var gate_out: Array = []
	for gate: GateState in gates:
		gate_out.append({"cell": DataCheck.cell_data(gate.cell), "fixed": gate.fixed, "broken": gate.broken})
	var tower_out: Array = []
	for tower: TowerState in towers:
		tower_out.append({
			"cell": DataCheck.cell_data(tower.cell), "type": String(tower.type), "tier": tower.tier,
			"spec": tower.spec, "aim": AIM_NAMES[tower.aim], "reload": tower.reload,
			"spent_now": tower.spent_now, "spent_before": tower.spent_before,
		})
	var enemy_out: Array = []
	for enemy: EnemyState in enemies:
		var item: Dictionary = {
			"id": enemy.id, "type": String(enemy.type), "wave": enemy.wave, "health": enemy.health,
			"max_health": enemy.max_health, "bubble": enemy.bubble, "bubble_ticks": enemy.bubble_ticks,
			"slow_pct": enemy.slow_pct, "slow_ticks": enemy.slow_ticks, "summon_at": enemy.summon_at,
			"breaking": enemy.breaking,
		}
		if enemy.flying:
			item["fly_from"] = DataCheck.cell_data(enemy.fly_from)
			item["flown"] = enemy.flown
		else:
			item["from"] = DataCheck.cell_data(enemy.from_cell)
			item["to"] = DataCheck.cell_data(enemy.to_cell)
			item["progress"] = enemy.progress
		enemy_out.append(item)
	var release_out: Array = []
	for release: Release in _releases:
		var item: Dictionary = {
			"enemy": String(release.enemy), "wave": release.wave, "left": release.left,
			"next": release.next, "gap": release.gap,
		}
		if catalog.enemy(release.enemy).flying:
			item["pos"] = DataCheck.cell_data(release.pos)
		else:
			item["from"] = DataCheck.cell_data(release.from_cell)
			item["to"] = DataCheck.cell_data(release.to_cell)
			item["progress"] = release.progress
		release_out.append(item)
	var built_out: Array = []
	for type: StringName in _built:
		built_out.append(String(type))
	return {
		"format": FORMAT, "level": level.to_data(), "relaxed": relaxed, "effects": [], "risk": [],
		"tick": tick, "phase": PHASE_NAMES[phase], "waves_started": waves_started,
		"running": running.duplicate(), "wave_start": _wave_start.duplicate(),
		"gold": gold, "lives": lives, "start_lives": start_lives, "gates_in_hand": gates_in_hand,
		"gates": gate_out, "towers": tower_out, "enemies": enemy_out, "releases": release_out,
		"next_id": _next_id,
		"record": {
			"early_calls": _early_calls, "max_towers": _max_towers, "built": built_out,
			"max_tier": _max_tier, "max_gates_at_start": _max_gates_at_start,
			"gates_whole": _gates_whole, "waves_cleared": _waves_cleared,
		},
	}


## Null when any field is invalid. All or nothing.
static func from_data(data: Variant, stats: Catalog) -> Battle:
	if stats == null or stats.rules == null:
		return null
	var chk: DataCheck = DataCheck.new("battle")
	var battle: Battle = Battle.new()
	if not battle._load(data, stats, chk) or not chk.ok():
		return null
	return battle


func _load(data: Variant, stats: Catalog, chk: DataCheck) -> bool:
	if not chk.object(data, "", SAVE_KEYS) or not chk.ok():
		return false
	var top: Dictionary = data
	chk.integer(top, "format", "", FORMAT, FORMAT)
	var level_data: LevelData = LevelData.from_data(top["level"], stats)
	if level_data == null:
		chk.fail("level", "is not a valid level")
		return false
	_setup(level_data, stats)
	var rules: GameRules = stats.rules
	relaxed = chk.boolean(top, "relaxed", "")
	# Phase 5 battles hold no effects (Twists and cards come in phase 7).
	chk.array(top, "effects", "", 0, 0)
	chk.array(top, "risk", "", 0, 0)
	tick = chk.integer(top, "tick", "", 0, BIG)
	var phase_value: Variant = top["phase"]
	if not DataCheck.is_string(phase_value) or not ["build", "wave"].has(String(phase_value)):
		chk.fail("phase", "must be build or wave")
		return false
	phase = Phase.BUILD if String(phase_value) == "build" else Phase.WAVE
	var wave_total: int = level.waves.size()
	waves_started = chk.integer(top, "waves_started", "", 0, wave_total)
	var run_list: Array = chk.array(top, "running", "", 0, rules.max_waves_running)
	for i: int in run_list.size():
		var w: int = chk.whole(run_list[i], "running[%d]" % i, 0, waves_started - 1, 1, -1)
		if not running.is_empty() and w <= running.back():
			chk.fail("running[%d]" % i, "must be in start order")
		running.append(w)
	var start_list: Array = chk.array(top, "wave_start", "", waves_started, waves_started)
	for i: int in start_list.size():
		var at: int = chk.whole(start_list[i], "wave_start[%d]" % i, 0, tick)
		if not _wave_start.is_empty() and at < _wave_start.back():
			chk.fail("wave_start[%d]" % i, "must not be before the wave before it")
		_wave_start.append(at)
	if not chk.ok():
		return false
	if phase == Phase.BUILD and (not running.is_empty() or waves_started >= wave_total):
		chk.fail("phase", "a build phase has no wave running and a wave to come")
	if phase == Phase.WAVE and running.is_empty():
		chk.fail("phase", "a wave phase has a wave running")
	gold = chk.integer(top, "gold", "", 0, BIG)
	lives = chk.integer(top, "lives", "", 1, 1000000, 1, 1)
	start_lives = chk.integer(top, "start_lives", "", 1, 1000000, 1, 1)
	gates_in_hand = chk.integer(top, "gates_in_hand", "", 0, rules.max_gates)
	_load_gates(top["gates"], chk)
	if not chk.ok():
		return false
	_refresh_dist()
	if phase == Phase.BUILD and map.seals(closed_cells()):
		chk.fail("gates", "seal every road")
	_load_towers(top["towers"], chk)
	_next_id = chk.integer(top, "next_id", "", 0, ID_CEILING)
	_load_enemies(top["enemies"], chk)
	_load_releases(top["releases"], chk)
	_load_record(top["record"], chk)
	return chk.ok()


func _load_gates(data: Variant, chk: DataCheck) -> void:
	var list: Array = chk.array_value(data, "gates", 0, level.sockets.size())
	for i: int in list.size():
		var path: String = "gates[%d]" % i
		if not chk.object(list[i], path, ["cell", "fixed", "broken"]) or not chk.ok():
			return
		var item: Dictionary = list[i]
		var gate: GateState = GateState.new()
		gate.cell = chk.cell(item["cell"], path + ".cell", level.rows)
		if not level.sockets.has(gate.cell):
			chk.fail(path + ".cell", "must be a socket")
		if not gates.is_empty() and not Sim.cell_before(gates.back().cell, gate.cell):
			chk.fail(path + ".cell", "must be in cell order with one gate per socket")
		gate.fixed = chk.boolean(item, "fixed", path)
		gate.broken = chk.boolean(item, "broken", path)
		if gate.fixed:
			chk.fail(path + ".fixed", "fixed gates come from Twists (phase 7)")
		if gate.broken and phase == Phase.BUILD:
			chk.fail(path + ".broken", "gates mend when a build phase begins")
		gates.append(gate)
	if gates.size() + gates_in_hand != level.gates:
		chk.fail("gates", "placed and in hand must add up to the level's gates")


func _load_towers(data: Variant, chk: DataCheck) -> void:
	var list: Array = chk.array_value(data, "towers", 0, level.spots.size())
	for i: int in list.size():
		var path: String = "towers[%d]" % i
		if not chk.object(list[i], path, ["cell", "type", "tier", "spec", "aim", "reload", "spent_now", "spent_before"]) or not chk.ok():
			return
		var item: Dictionary = list[i]
		var tower: TowerState = TowerState.new()
		tower.cell = chk.cell(item["cell"], path + ".cell", level.rows)
		if level.kind_at(tower.cell) != LevelData.Kind.SPOT:
			chk.fail(path + ".cell", "must be a build spot")
		if not towers.is_empty() and not Sim.cell_before(towers.back().cell, tower.cell):
			chk.fail(path + ".cell", "must be in cell order with one tower per spot")
		tower.type = chk.ident(item, "type", path)
		if not _offered(tower.type):
			chk.fail(path + ".type", "must be a tower this level offers")
			continue
		tower.tier = chk.integer(item, "tier", path, 1, 3, 1, 1)
		tower.spec = chk.integer(item, "spec", path, -1, 1, 1, -1)
		if (tower.tier < 3) != (tower.spec == -1):
			chk.fail(path + ".spec", "must be -1 below tier 3 and 0 or 1 at tier 3")
			continue
		var aim_value: Variant = item["aim"]
		if not DataCheck.is_string(aim_value) or not AIM_NAMES.has(String(aim_value)):
			chk.fail(path + ".aim", "must be first, last or strong")
		else:
			tower.aim = AIM_NAMES.find(String(aim_value)) as TowerState.Aim
		# Between ticks a timer is 0 to the tower's own reload (5.2). It starts at 0. A tick
		# drains it by MS_PER_TICK x 100 = 5000, and every reload_ms x 100 is at least that,
		# so a shot taken at 0 or below lands it back at 0 or more; an idle tower sets 0; an
		# upgrade caps it at the new reload. Phase 7: recheck the floor once Bakery boosts
		# make the drain larger.
		tower.reload = chk.integer(item, "reload", path, 0, _stats(tower).reload_ms * 100)
		tower.spent_now = chk.integer(item, "spent_now", path, 0, BIG)
		tower.spent_before = chk.integer(item, "spent_before", path, 0, BIG)
		if phase == Phase.WAVE and tower.spent_now != 0:
			chk.fail(path + ".spent_now", "is 0 during a wave")
		towers.append(tower)
		if chk.ok():
			_refresh_reach(tower)


func _load_enemies(data: Variant, chk: DataCheck) -> void:
	var list: Array = chk.array_value(data, "enemies", 0, MAX_ENEMIES)
	if phase == Phase.BUILD and not list.is_empty():
		chk.fail("enemies", "a build phase has no creatures")
		return
	var base_keys: PackedStringArray = [
		"id", "type", "wave", "health", "max_health", "bubble", "bubble_ticks", "slow_pct",
		"slow_ticks", "summon_at", "breaking",
	]
	for i: int in list.size():
		var path: String = "enemies[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			chk.fail(path, "must be an object")
			return
		var item: Dictionary = list[i]
		var enemy: EnemyState = EnemyState.new()
		enemy.type = chk.ident(item, "type", path)
		var type: EnemyType = catalog.enemy(enemy.type)
		if type == null:
			chk.fail(path + ".type", "names no creature")
			return
		var keys: PackedStringArray = base_keys.duplicate()
		keys.append_array(["fly_from", "flown"] if type.flying else ["from", "to", "progress"])
		if not chk.object(item, path, keys) or not chk.ok():
			return
		enemy.id = chk.integer(item, "id", path, 0, ID_CEILING - 1)
		if enemy.id >= _next_id or (not enemies.is_empty() and enemy.id <= enemies.back().id):
			chk.fail(path + ".id", "must be in id order and below next_id")
		enemy.wave = chk.integer(item, "wave", path, 0, level.waves.size() - 1)
		if not running.has(enemy.wave):
			chk.fail(path + ".wave", "must be a running wave")
			return
		_derive(enemy)
		enemy.max_health = chk.integer(item, "max_health", path, 1, BIG, 1, 1)
		enemy.health = chk.integer(item, "health", path, 1, enemy.max_health, 1, 1)
		enemy.bubble = chk.boolean(item, "bubble", path)
		var bubble_cap: int = catalog.rules.bubble_ms / Sim.MS_PER_TICK if type.bubble else 0
		enemy.bubble_ticks = chk.integer(item, "bubble_ticks", path, 0, bubble_cap)
		if (enemy.bubble and not type.bubble) or (enemy.bubble and enemy.bubble_ticks > 0) \
				or (type.bubble and not enemy.bubble and enemy.bubble_ticks == 0):
			chk.fail(path + ".bubble", "does not match the bubble timer")
		enemy.slow_pct = chk.integer(item, "slow_pct", path, 0, 90)
		enemy.slow_ticks = chk.integer(item, "slow_ticks", path, 0, 60000 / Sim.MS_PER_TICK)
		if (enemy.slow_pct == 0) != (enemy.slow_ticks == 0):
			chk.fail(path + ".slow_ticks", "a slow has both a percent and a time")
		if type.summon.is_empty():
			enemy.summon_at = chk.integer(item, "summon_at", path, 0, 0)
		else:
			var every: int = int(type.summon["every_ms"]) / Sim.MS_PER_TICK
			enemy.summon_at = chk.integer(item, "summon_at", path, tick, tick + every, 1, tick)
		enemy.breaking = chk.integer(item, "breaking", path, 0, 0)
		if type.flying:
			var high: Vector2i = Vector2i(Sim.MAP_COLUMNS * Sim.UNIT, level.rows * Sim.UNIT)
			var start: Vector2i = chk.pair(item["fly_from"], path + ".fly_from", 0, maxi(high.x, high.y))
			if start.x > high.x or start.y > high.y:
				chk.fail(path + ".fly_from", "must be inside the map")
			_launch(enemy, start)
			enemy.flown = chk.integer(item, "flown", path, 0, maxi(enemy.fly_length - 1, 0))
			if enemy.fly_length <= 0:
				chk.fail(path + ".fly_from", "must not be the base center")
		else:
			_load_step(item, path, enemy.breaker, chk)
			enemy.from_cell = _loaded_from
			enemy.to_cell = _loaded_to
			enemy.progress = _loaded_progress
		if not chk.ok():
			return
		_place(enemy)
		enemy.prev_pos = enemy.pos
		enemies.append(enemy)
		if enemy.summon_at > 0:
			_summoners.append(enemy)


var _loaded_from: Vector2i = Vector2i.ZERO
var _loaded_to: Vector2i = Vector2i.ZERO
var _loaded_progress: int = 0


## A walker's step: two joined road cells, or one cell with the walker at its center,
## with an open route on from there.
func _load_step(item: Dictionary, path: String, breaker: bool, chk: DataCheck) -> void:
	_loaded_from = chk.cell(item["from"], path + ".from", level.rows)
	_loaded_to = chk.cell(item["to"], path + ".to", level.rows)
	_loaded_progress = chk.integer(item, "progress", path, 0, Sim.UNIT)
	if not chk.ok():
		return
	var gap: Vector2i = _loaded_to - _loaded_from
	if not map.is_road(_loaded_from) or not map.is_road(_loaded_to):
		chk.fail(path, "must stand on road cells")
	elif absi(gap.x) + absi(gap.y) > 1:
		chk.fail(path, "must walk between joined cells")
	elif gap == Vector2i.ZERO and _loaded_progress != Sim.UNIT:
		chk.fail(path + ".progress", "must be at the cell center")
	var closed: Array[Vector2i] = closed_cells()
	var dist: PackedInt32Array = _free_dist if breaker else _dist
	if closed.has(_loaded_from) or closed.has(_loaded_to) or dist[map.index(_loaded_to)] < 0:
		chk.fail(path, "must have an open route to the base")


func _load_releases(data: Variant, chk: DataCheck) -> void:
	var list: Array = chk.array_value(data, "releases", 0, MAX_RELEASES)
	if phase == Phase.BUILD and not list.is_empty():
		chk.fail("releases", "a build phase has no releases")
		return
	for i: int in list.size():
		var path: String = "releases[%d]" % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			chk.fail(path, "must be an object")
			return
		var item: Dictionary = list[i]
		var release: Release = Release.new()
		release.enemy = chk.ident(item, "enemy", path)
		var type: EnemyType = catalog.enemy(release.enemy)
		if type == null:
			chk.fail(path + ".enemy", "names no creature")
			return
		var keys: PackedStringArray = ["enemy", "wave", "left", "next", "gap"]
		keys.append_array(["pos"] if type.flying else ["from", "to", "progress"])
		if not chk.object(item, path, keys) or not chk.ok():
			return
		release.wave = chk.integer(item, "wave", path, 0, level.waves.size() - 1)
		if not running.has(release.wave):
			chk.fail(path + ".wave", "must be a running wave")
		release.left = chk.integer(item, "left", path, 1, 200, 1, 1)
		release.gap = chk.integer(item, "gap", path, 1, 60000 / Sim.MS_PER_TICK, 1, 1)
		release.next = chk.integer(item, "next", path, tick, tick + release.gap, 1, tick)
		if type.flying:
			var high: Vector2i = Vector2i(Sim.MAP_COLUMNS * Sim.UNIT, level.rows * Sim.UNIT)
			release.pos = chk.pair(item["pos"], path + ".pos", 0, maxi(high.x, high.y))
			if release.pos.x > high.x or release.pos.y > high.y:
				chk.fail(path + ".pos", "must be inside the map")
		else:
			_load_step(item, path, false, chk)
			release.from_cell = _loaded_from
			release.to_cell = _loaded_to
			release.progress = _loaded_progress
		if not chk.ok():
			return
		_releases.append(release)


func _load_record(data: Variant, chk: DataCheck) -> void:
	if not chk.object(data, "record", RECORD_KEYS):
		return
	var item: Dictionary = data
	_early_calls = chk.integer(item, "early_calls", "record", 0, waves_started)
	_max_towers = chk.integer(item, "max_towers", "record", towers.size(), LevelData.MAX_SPOTS)
	var list: Array = chk.array(item, "built", "record", 0, level.towers.size())
	for i: int in list.size():
		var type: StringName = chk.ident_value(list[i], "record.built[%d]" % i)
		if not _offered(type) or _built.has(type):
			chk.fail("record.built[%d]" % i, "must be a tower this level offers, once")
		_built.append(type)
	for tower: TowerState in towers:
		if not _built.has(tower.type):
			chk.fail("record.built", "must hold every tower type on the map")
	_max_tier = chk.integer(item, "max_tier", "record", 0, 3)
	for tower: TowerState in towers:
		if tower.tier > _max_tier:
			chk.fail("record.max_tier", "must be at least every tower's tier")
	_max_gates_at_start = chk.integer(item, "max_gates_at_start", "record", 0, catalog.rules.max_gates)
	_gates_whole = chk.boolean(item, "gates_whole", "record", true)
	_waves_cleared = chk.integer(item, "waves_cleared", "record", 0, waves_started)
