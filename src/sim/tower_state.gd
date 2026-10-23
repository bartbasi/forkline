# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TowerState
extends RefCounted
## One tower on the map. Read only outside src/sim/.

enum Aim { FIRST, LAST, STRONG }                       # RULES 8.2; FIRST is the default

var cell: Vector2i = Vector2i(-1, -1)
var type: StringName = &""
var tier: int = 1                                      # 1, 2 or 3
var spec: int = -1                                     # -1 below tier 3, else 0 or 1
var aim: Aim = Aim.FIRST
var reload: int = 0                                    # 1/100 ms until it may fire; 0 or less is ready
var spent_now: int = 0                                 # bought in the current build phase: refunded in full
var spent_before: int = 0                              # every other purchase: refunded at the refund percent

## Internal to src/sim/: cell indexes a walker in reach could stand on, rebuilt when
## the tower is built or upgraded.
var near_cells: PackedInt32Array = PackedInt32Array()
