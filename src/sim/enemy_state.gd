# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name EnemyState
extends RefCounted
## One creature on the map. Read only outside src/sim/.

var id: int = 0
var type: StringName = &""
var wave: int = 0
var health: int = 1
var max_health: int = 1
var bubble: bool = false                               # the bubble is up
var slow_pct: int = 0
var slow_ticks: int = 0
var flying: bool = false
var breaker: bool = false                              # walks the breaker route (4.5)
var from_cell: Vector2i = Vector2i.ZERO                # walkers: the step being walked
var to_cell: Vector2i = Vector2i.ZERO
var progress: int = 0                                  # sub-units along the step, 0 to UNIT
var fly_from: Vector2i = Vector2i.ZERO                 # flyers: a straight line in sub-units
var fly_to: Vector2i = Vector2i.ZERO
var fly_length: int = 0
var flown: int = 0
var breaking: int = 0                                  # 1/100 ms of breaking left; 0 when not breaking
var pos: Vector2i = Vector2i.ZERO                      # sub-units, after this tick
var prev_pos: Vector2i = Vector2i.ZERO                 # sub-units, after the last tick, or where it last landed
                                                       # after a jump this tick (docs/ARCHITECTURE.md 14.3)
var out_of_reach: bool = false                         # in a tunnel or on a twin step (RULES 8.8); never saved

## Internal to src/sim/. Worked out at spawn from the type, the wave's strength and
## effects, and again on load, so they are not saved.
var armor: int = 0
var speed: int = 0                                     # hundredths of a tile a second, with speed ups (RULES 6.3)
var speed_pct: int = 100                               # speed_pct effects on its wave (contract 2.8)
var lives: int = 1
var bounty: int = 1
var break_ms: int = 0                                  # a gate breaker's time per gate, 0 for none (RULES 7.7)
var watched: bool = false                              # it has a speed up or a health release (RULES 6.3)
var to_node: int = -1                                  # walkers: the node it is heading to (docs/ARCHITECTURE.md 14.3)
## Internal and saved: ticks until a popped bubble is back (0 when up), the tick of
## the next summon batch (0 for none), the tick of the next heal (0 for none), the
## speed ups taken so far, and whether its health release has begun.
var bubble_ticks: int = 0
var summon_at: int = 0
var heal_at: int = 0
var ups: int = 0
var released: bool = false
