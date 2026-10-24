# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name StarText
extends RefCounted
## The three star rules of a level as plain sentences (RULES 10, docs/ARCHITECTURE.md
## 2.7). The sentences are built from the level's star3 data, its number and the
## Catalog, so a tower's name is never written here.

const BIT_WIN: int = 1
const BIT_LIVES: int = 2
const BIT_CHALLENGE: int = 4


static func win() -> String:
	return "Win the level."


## "Keep 15 lives." The number is rules.json star2_lives.
static func lives(catalog: Catalog) -> String:
	return "Keep %d lives." % catalog.rules.star2_lives


## The level's own challenge, from its kind, its number and the tower's plural.
static func challenge(level: LevelData, catalog: Catalog) -> String:
	var kind: StringName = level.star3.get("kind", &"")
	var value: int = int(level.star3.get("value", 0))
	match kind:
		&"no_lives_lost":
			return "Lose no lives."
		&"towers_at_most":
			return "Have at most %d %s." % [value, _plural(value, "tower", "towers")]
		&"tower_ban":
			var type: TowerType = catalog.tower(level.star3.get("tower", &""))
			return "Build no %s." % (type.plural if type != null else "towers of that kind")
		&"gates_at_most":
			if value == 0:
				return "Use no gates."
			return "Use at most %d %s." % [value, _plural(value, "gate", "gates")]
		&"tier_at_most":
			return "No tower above tier %d." % value
		&"early_calls_at_least":
			return "Call %d %s early." % [value, _plural(value, "wave", "waves")]
		&"kinds_at_most":
			return "Use at most %d %s of tower." % [value, _plural(value, "kind", "kinds")]
		&"gates_whole":
			return "Use every gate and keep them whole."
	return ""


## The three lines, star 1 to star 3.
static func lines(level: LevelData, catalog: Catalog) -> PackedStringArray:
	return PackedStringArray([win(), lives(catalog), challenge(level, catalog)])


## How many stars a bit mask holds.
static func count(bits: int) -> int:
	return (bits & BIT_WIN) + ((bits >> 1) & 1) + ((bits >> 2) & 1)


static func _plural(value: int, one: String, many: String) -> String:
	return one if value == 1 else many
