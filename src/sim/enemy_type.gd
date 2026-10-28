# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name EnemyType
extends RefCounted
## One creature or boss from data/stats/enemies.json, in the file's units
## (docs/ARCHITECTURE.md 2.6). Numbers are at strength 100. Read only.

var id: StringName = &""
var name: String = ""
var info: String = ""
var health: int = 1
var armor: int = 0
var speed: int = 0
var lives: int = 1
var bounty: int = 1
var flying: bool = false
var boss: bool = false
var bubble: bool = false
var heal: int = 0
var heal_reach: int = 0
var heal_ms: int = 0
var split_into: StringName = &""
var split_count: int = 0
var split_gap_ms: int = 0
var break_ms: int = 0
var regrow: int = 0                                    # RULES 6.2: regrow this much every regrow_ms; 0 for none
var regrow_ms: int = 0
var mist: bool = false                                 # RULES 6.2: hides the creatures on its tile and the four next to it
var dazzle: bool = false                               # RULES 6.2: towers that can aim at it aim at it first
var nap_ms: int = 0                                    # RULES 6.2: naps this long instead of its first defeat; 0 for none
var dig_first_ms: int = 0                              # RULES 6.3: digs under dig_first_ms after it appears, then every
var dig_every_ms: int = 0                              # dig_every_ms, for dig_ms each time; 0 for none
var dig_ms: int = 0
## {"enemy": StringName, "count": int, "every_ms": int, "gap_ms": int}, or {} for none.
var summon: Dictionary = {}
## {"at_pct": Array[int], "add": int}, or {} for none.
var speed_up: Dictionary = {}
## {"at_pct": int, "enemy": StringName, "count": int, "gap_ms": int}, or {} for none.
var release: Dictionary = {}
