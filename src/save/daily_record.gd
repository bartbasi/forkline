# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DailyRecord
extends RefCounted
## The daily challenge's best result and streak, saved in daily.json
## (docs/ARCHITECTURE.md 3.5, 5.5; RULES 15).

const FORMAT: int = 1
## Ceiling of the numbers in a result (5.5). A run has 18 waves and far fewer lives.
const NUMBER_MAX: int = 1000
const RESULT_KEYS: PackedStringArray = ["won", "waves", "lives"]

var day: String = ""                                   # "" or the day of best
var best: Dictionary = {}                              # that day's best {"won": bool, "waves": int, "lives": int}; {} for none
var streak: int = 0
var streak_day: String = ""                            # the last counted day


## A daily belonging to finished_day has ended with result ({"won", "waves", "lives"} from
## RunSession.result(); other keys are ignored). The streak moves by Daily.streak_after.
## A later day than the record's replaces the best; the same day keeps the better result
## by Daily.is_better; an earlier day leaves it alone. Day keys compare as text, which is
## date order. A finished_day that is not a day key changes nothing.
func record_finish(finished_day: String, result: Dictionary) -> void:
	if not RunSeeds.is_day_key(finished_day):
		return
	var after: Dictionary = Daily.streak_after(streak, streak_day, finished_day)
	streak = after["streak"]
	streak_day = after["day"]
	var clean: Dictionary = _clean(result)
	if day == "" or finished_day > day:
		day = finished_day
		best = clean
	elif finished_day == day and Daily.is_better(clean, best):
		best = clean


func to_data() -> Dictionary:
	return {"format": FORMAT, "day": day, "best": best.duplicate(), "streak": streak, "streak_day": streak_day}


## Any bad field falls back to its default. Unknown keys are ignored. A day without a
## best, or a best without a day, falls back to neither.
static func from_data(data: Variant) -> DailyRecord:
	var record: DailyRecord = new()
	if typeof(data) != TYPE_DICTIONARY:
		return record
	var top: Dictionary = data
	record.day = _read_day(top.get("day", null))
	record.best = _read_result(top.get("best", null))
	if record.day == "" or record.best.is_empty():
		record.day = ""
		record.best = {}
	var streak_value: Variant = top.get("streak", null)
	if DataCheck.is_whole(streak_value) and int(streak_value) >= 0 and int(streak_value) <= Daily.STREAK_MAX:
		record.streak = int(streak_value)
	record.streak_day = _read_day(top.get("streak_day", null))
	return record


## A day key, or "".
static func _read_day(value: Variant) -> String:
	if not DataCheck.is_string(value) or String(value).length() != 10:
		return ""
	var text: String = String(value)
	return text if RunSeeds.is_day_key(text) else ""


## Exactly won (a bool), waves and lives (whole, 0 to NUMBER_MAX), as ints; else {}.
static func _read_result(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var item: Dictionary = value
	if item.size() != RESULT_KEYS.size():
		return {}
	for key: String in RESULT_KEYS:
		if not item.has(key):
			return {}
	if typeof(item["won"]) != TYPE_BOOL:
		return {}
	for key: String in ["waves", "lives"]:
		var number: Variant = item[key]
		if not DataCheck.is_whole(number) or int(number) < 0 or int(number) > NUMBER_MAX:
			return {}
	return {"won": item["won"], "waves": int(item["waves"]), "lives": int(item["lives"])}


## The three result fields as a bool and two ints from 0 to NUMBER_MAX. A field that is
## missing or of the wrong type counts as false or 0, as Daily.is_better reads it.
static func _clean(result: Dictionary) -> Dictionary:
	var won: Variant = result.get("won", false)
	var out: Dictionary = {"won": typeof(won) == TYPE_BOOL and won}
	for key: String in ["waves", "lives"]:
		var number: Variant = result.get(key, 0)
		out[key] = clampi(int(number), 0, NUMBER_MAX) if DataCheck.is_whole(number) else 0
	return out
