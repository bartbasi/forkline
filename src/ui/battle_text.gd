# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BattleText
extends RefCounted
## The words and numbers of the battle panels, as pure functions.
##
## Tower, path and creature names are never written here. They come from the
## Catalog (data/stats/), so a rename changes data only (docs/ARCHITECTURE.md
## 2.1). What is written here is fixed UI text: labels like "Damage", the
## refusal messages, and number formats.
##
## Units follow the contract: reach and splash in hundredths of a tile, time in
## milliseconds, speed in hundredths of a tile a second.

const AIM_NAMES: PackedStringArray = ["First", "Last", "Strong"]


## Hundredths of a tile as tiles with no needless zeros: 250 is "2.5", 75 is "0.75".
static func tiles(hundredths: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = hundredths / 100
	var frac: int = hundredths % 100
	if frac == 0:
		return str(whole)
	if frac % 10 == 0:
		@warning_ignore("integer_division")
		return "%d.%d" % [whole, frac / 10]
	return "%d.%02d" % [whole, frac]


## Milliseconds as seconds with one decimal: 1000 is "1.0".
static func seconds(ms: int) -> String:
	@warning_ignore("integer_division")
	return "%d.%d" % [ms / 1000, (ms % 1000) / 100]


## Speed in hundredths of a tile a second as tiles a second with two decimals.
static func speed(hundredths: int) -> String:
	return "%.2f" % (float(hundredths) / 100.0)


## Attacks a second for a reload time and a Bakery rate boost (RULES 5.2, 9.3), one decimal.
static func rate(reload_ms: int, boost_pct: int = 0) -> String:
	if reload_ms <= 0:
		return "0.0"
	return "%.1f" % (float(100 + boost_pct) * 10.0 / float(reload_ms))


static func entrance_letter(entrance: int) -> String:
	return char(64 + clampi(entrance, 1, 4))


static func aim_name(aim: int) -> String:
	if aim < 0 or aim >= AIM_NAMES.size():
		return ""
	return AIM_NAMES[aim]


## What a tower can hit, in full words.
static func hits_text(numbers: Dictionary) -> String:
	var ground: bool = bool(numbers.get("hits_ground", false))
	var air: bool = bool(numbers.get("hits_air", false))
	if ground and air:
		return "Walkers and flyers"
	if air:
		return "Flyers"
	if ground:
		return "Walkers"
	return "Nothing"


## The same in one short word, for the narrow before and after rows.
static func hits_short(numbers: Dictionary) -> String:
	var ground: bool = bool(numbers.get("hits_ground", false))
	var air: bool = bool(numbers.get("hits_air", false))
	if ground and air:
		return "Both"
	if air:
		return "Flyers"
	if ground:
		return "Walkers"
	return "None"


## One short, plain sentence for a refusal of docs/ARCHITECTURE.md 3.1. `need` is
## the gold still missing, used by `too_poor`.
static func refusal(reason: StringName, need: int = 0) -> String:
	match reason:
		&"over":
			return "The battle is over."
		&"not_a_spot":
			return "You can only build on a build spot."
		&"occupied":
			return "A tower is already there."
		&"not_offered":
			return "This level does not offer that tower."
		&"too_poor":
			if need > 0:
				return "Need %d more gold." % need
			return "Not enough gold."
		&"no_tower":
			return "There is no tower there."
		&"top_tier":
			return "This tower is fully upgraded."
		&"tier_cap":
			return "This level caps the tower tier."
		&"pick_spec":
			return "Pick a path first."
		&"bad_spec":
			return "That path is not available."
		&"no_selling":
			return "Towers cannot be sold on this level."
		&"no_aim":
			return "This tower has no targeting."
		&"bad_aim":
			return "That targeting is not available."
		&"gates_locked":
			return "Gates are locked until the wave is over."
		&"not_a_socket":
			return "Gates go on the marked roads."
		&"has_gate":
			return "A gate is already there."
		&"no_gate":
			return "There is no gate there."
		&"no_gates_left":
			return "No gates left in hand."
		&"fixed_gate":
			return "That gate cannot be moved."
		&"would_seal":
			return "That would close every road."
		&"no_more_waves":
			return "That was the last wave."
		&"still_spawning":
			return "The wave is still arriving."
		&"too_many_waves":
			return "Too many waves on the map."
		&"risk_waiting":
			return "A risk card is already waiting."
		&"bad_effect":
			return "That card cannot be used."
	return "That did not work."


## Gold still missing for a refusal, from the price and the gold in hand.
static func shortfall(reason: StringName, price: int, gold: int) -> int:
	if reason == &"too_poor":
		return maxi(0, price - gold)
	return 0


## The rows of a tower's own numbers, as [label, value] pairs, for the build card
## and the tapped tower (RULES 9.3). `numbers` comes from the Battle queries.
static func tower_rows(numbers: Dictionary, kind: StringName) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var got_pct: int = int(numbers.get("got_pct", 0))
	var got_damage: int = int(numbers.get("got_damage", 0))
	var reach: int = int(numbers.get("reach", 0))
	if kind == &"boost":
		rows.append(PackedStringArray(["Rate boost", "+%d%%" % int(numbers.get("boost_pct", 0))]))
		rows.append(PackedStringArray(["Damage bonus", "+%d" % int(numbers.get("boost_damage", 0))]))
		rows.append(PackedStringArray(["Reach", "%s tiles" % tiles(reach)]))
		if numbers.has("boosting"):
			rows.append(PackedStringArray(["Boosting now", str(int(numbers["boosting"]))]))
		return rows
	if kind == &"slow":
		rows.append(PackedStringArray(["Slow", "%d%%" % int(numbers.get("slow_pct", 0))]))
		rows.append(PackedStringArray(["Range", "%s tiles" % tiles(reach)]))
		rows.append(PackedStringArray(["Linger", "%s s" % seconds(int(numbers.get("slow_ms", 0)))]))
		rows.append(PackedStringArray(["Affects", hits_text(numbers)]))
		return rows
	var damage: String = str(int(numbers.get("damage", 0)))
	if got_damage > 0:
		damage += " +%d" % got_damage
	rows.append(PackedStringArray(["Damage", damage]))
	rows.append(PackedStringArray(["Rate", "%s/s" % rate(int(numbers.get("reload_ms", 0)), got_pct)]))
	rows.append(PackedStringArray(["Range", "%s tiles" % tiles(reach)]))
	rows.append(PackedStringArray(["Hits", hits_text(numbers)]))
	if int(numbers.get("splash", 0)) > 0:
		rows.append(PackedStringArray(["Splash", "%s tiles" % tiles(int(numbers["splash"]))]))
	if bool(numbers.get("pierce", false)):
		rows.append(PackedStringArray(["Armor", "Ignored"]))
	if int(numbers.get("targets", 1)) > 1:
		rows.append(PackedStringArray(["Targets", str(int(numbers["targets"]))]))
	if int(numbers.get("slow_pct", 0)) > 0:
		rows.append(PackedStringArray(["Slow", "%d%% for %s s" % [int(numbers["slow_pct"]), seconds(int(numbers.get("slow_ms", 0)))]]))
	if got_pct > 0 or got_damage > 0:
		rows.append(PackedStringArray(["Boost received", "+%d%% rate, +%d damage" % [got_pct, got_damage]]))
	return rows


## The numbers an upgrade changes, as one entry each: {"label", "before", "after"}.
## Only numbers that differ are listed (RULES 9.5). `got_pct` is the Bakery boost
## the tower gets now, so a rate is shown as it will really be.
static func change_rows(before: Dictionary, after: Dictionary, kind: StringName, got_pct: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind != &"slow" and kind != &"boost":
		_change(out, "Damage", str(int(before.get("damage", 0))), str(int(after.get("damage", 0))))
		_change(out, "Rate", rate(int(before.get("reload_ms", 0)), got_pct), rate(int(after.get("reload_ms", 0)), got_pct))
		_change(out, "Targets", str(int(before.get("targets", 1))), str(int(after.get("targets", 1))))
	if kind == &"boost":
		_change(out, "Rate boost", "+%d%%" % int(before.get("boost_pct", 0)), "+%d%%" % int(after.get("boost_pct", 0)))
		_change(out, "Damage bonus", "+%d" % int(before.get("boost_damage", 0)), "+%d" % int(after.get("boost_damage", 0)))
	_change(out, "Range" if kind != &"boost" else "Reach", tiles(int(before.get("reach", 0))), tiles(int(after.get("reach", 0))))
	_change(out, "Splash", _tiles_or_none(int(before.get("splash", 0))), _tiles_or_none(int(after.get("splash", 0))))
	_change(out, "Slow", _percent_or_none(int(before.get("slow_pct", 0))), _percent_or_none(int(after.get("slow_pct", 0))))
	_change(out, "Linger", _seconds_or_none(int(before.get("slow_ms", 0))), _seconds_or_none(int(after.get("slow_ms", 0))))
	_change(out, "Hits", hits_short(before), hits_short(after))
	_change(out, "Armor", "Blunts" if not bool(before.get("pierce", false)) else "Ignored", "Blunts" if not bool(after.get("pierce", false)) else "Ignored")
	return out


static func _tiles_or_none(hundredths: int) -> String:
	return tiles(hundredths)


static func _percent_or_none(pct: int) -> String:
	return "%d%%" % pct


static func _seconds_or_none(ms: int) -> String:
	return "%s s" % seconds(ms) if ms > 0 else "0 s"


static func _change(out: Array[Dictionary], label: String, before_text: String, after_text: String) -> void:
	if before_text != after_text:
		out.append({"label": label, "before": before_text, "after": after_text})


## The sentence under the sell button: what the refund is made of (RULES 4.6).
## `now` was bought in this build phase, `before` earlier; `percent` is the refund rule.
static func refund_text(now: int, before: int, percent: int) -> String:
	if now > 0 and before > 0:
		return "Full price for the %d bought this build phase, %d%% of the other %d." % [now, percent, before]
	if before > 0:
		return "%d%% of the %d you paid." % [percent, before]
	return "Full refund: bought this build phase."


## The status lines of a tapped creature (RULES 9.4). Empty when there are none.
static func status_lines(numbers: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if int(numbers.get("slow_pct", 0)) > 0 and int(numbers.get("slow_ms", 0)) > 0:
		out.append("Slowed %d%% for %s s" % [int(numbers["slow_pct"]), seconds(int(numbers["slow_ms"]))])
	if bool(numbers.get("bubble", false)):
		out.append("Bubble up")
	elif int(numbers.get("bubble_ms", 0)) > 0:
		out.append("Bubble back in %s s" % seconds(int(numbers["bubble_ms"])))
	if int(numbers.get("breaking_ms", 0)) > 0:
		out.append("Breaking a gate: %s s left" % seconds(int(numbers["breaking_ms"])))
	return out
