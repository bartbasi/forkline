# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name InfoScreen
extends PageFrame
## Info (playbook 6.2): one full guide, opened only when tapped, always at the
## top. Short sections in the order a player meets things, each with a small
## real example drawn by src/theme/ code.
##
## Fixed text here never names a tower, creature, region, level or card
## (docs/ARCHITECTURE.md 2.1). Numbers come from `rules` (the rules.json keys)
## when the App has them and are left out of the sentence when it does not.
## Names under the pictures come from `names` (id to name, from data/stats/)
## and are left out when it is empty.

const PANEL_PADDING: float = 64.0

var _arts: Array[InfoArt] = []


func _init(rules: Dictionary = {}, names: Dictionary = {}) -> void:
	super("Info")
	for section: Dictionary in _sections(rules):
		_add_section(section, names)


func _relayout() -> void:
	super()
	var width: float = Layout.content_width(window_size.x, safe) - PANEL_PADDING
	for art: InfoArt in _arts:
		art.fit_width(width)


func _add_section(section: Dictionary, names: Dictionary) -> void:
	var box: VBoxContainer = UiKit.section()
	box.add_child(UiKit.heading(section["title"]))
	for paragraph: String in section["text"]:
		box.add_child(UiKit.label(paragraph))
	var art_kind: StringName = section.get("art", &"")
	if art_kind != &"":
		var art: InfoArt = InfoArt.new(art_kind, _captions(art_kind, names))
		_arts.append(art)
		box.add_child(art)
	column.add_child(box.get_parent())


## Names to draw under the towers or creatures, or none when `names` lacks them.
func _captions(art_kind: StringName, names: Dictionary) -> PackedStringArray:
	var ids: Array[StringName] = []
	if art_kind == &"towers":
		ids = Silhouettes.TOWERS
	elif art_kind == &"creatures":
		ids = Silhouettes.CREATURES
	var out: PackedStringArray = PackedStringArray()
	var found: bool = false
	for id: StringName in ids:
		var name_text: String = str(names.get(id, ""))
		found = found or not name_text.is_empty()
		out.append(name_text)
	return out if found else PackedStringArray()


## The guide, in the order a player meets things.
func _sections(rules: Dictionary) -> Array[Dictionary]:
	var refund: String = _percent(rules, "refund_pct", "part of")
	var star2: String = _star2_sentence(rules)
	var waves_at_once: String = _waves_sentence(rules)
	var run_stars: String = _count(rules, "run_stars", "enough")
	return [
		{"title": "The goal", "art": &"walk", "text": [
			"Night creatures walk down the roads toward your village. Every creature that gets through costs lives.",
			"Lose all your lives and the level is lost. Beat every wave and you win."]},
		{"title": "Build, then fight", "art": &"hud", "text": [
			"Each level starts with a build phase. Nothing moves and there is no timer. When you are ready, start the wave.",
			"Creatures then come in real time. You can run at 1x, 2x or 3x speed. You can pause at any moment and still build, upgrade, sell and look at things."]},
		{"title": "Gold", "text": [
			"You earn gold for each creature you defeat and for each wave you clear. Spend it on towers and upgrades.",
			"Sell a tower in the same build phase you bought it and you get all of it back. After that you get %s what you spent." % refund]},
		{"title": "Building towers", "art": &"spots", "text": [
			"Towers stand on the round build spots. Tap a spot, pick a tower, and look at its range ring before you confirm.",
			"Every tower has one job, and none is best everywhere. Mix them."]},
		{"title": "Telling towers apart", "art": &"towers", "text": [
			"Each tower looks different, so you can tell them apart by shape alone. Tap any tower to see its real numbers."]},
		{"title": "Upgrades", "art": &"tiers", "text": [
			"Every tower has three tiers. At tier 3 you pick one of two paths. The choice is permanent for that tower. Selling it is the only way to choose again.",
			"An upgrade shows its cost and the numbers before and after, so you can decide first."]},
		{"title": "Creatures", "art": &"creatures", "text": [
			"Creatures differ in speed, health and armor. Some fly, some heal the others, some break gates.",
			"The first time a new one is in the next wave, a card tells you about it. Tap any creature to see its real numbers."]},
		{"title": "Gates", "art": &"gates", "text": [
			"Some road tiles have a socket. Each level gives you a set number of gates, and a gate closes its socket.",
			"Creatures on foot always take the shortest open road to the village. A gate sends them away from one branch and past your towers.",
			"During a build phase, a line shows where they will go. You cannot close every road: that is refused. Gates are locked while a wave is running."]},
		{"title": "Flyers and gate breakers", "art": &"signals", "text": [
			"Flyers ignore roads and gates, so a gate is never the whole answer. A dotted line shows where they fly.",
			"Gate breakers go through a closed gate after a delay. Their route is a dashed line with a crack on each gate they will break."]},
		{"title": "Before each wave", "text": [
			"The wave preview lists what is coming, how many, and from which entrance, A to D. Tap a row for its numbers.",
			"You can call the next wave early to earn a bonus. The button shows the bonus. %s" % waves_at_once]},
		{"title": "Stars", "art": &"stars", "text": [
			"Win a level for one star. %s Each level has its own challenge for the third, shown on its card before you play." % star2,
			"Stars are kept for good. They open new regions."]},
		{"title": "Relaxed", "text": [
			"Relaxed gives you more lives and more gold to start. Nothing else changes.",
			"A Relaxed win earns one star, which is enough to keep going. The other stars need Normal. Normal is always the default."]},
		{"title": "More ways to play", "text": [
			"Roguelite is one run of many waves. After each wave you pick a card. Daily is one run a day, the same for everyone, and always Normal.",
			"Both open when you have earned %s stars. Everything in Forkline is earned by playing." % run_stars]},
	]


func _count(rules: Dictionary, key: String, fallback: String) -> String:
	if _has_number(rules, key):
		return str(int(rules[key]))
	return fallback


func _percent(rules: Dictionary, key: String, fallback: String) -> String:
	if _has_number(rules, key):
		return "%d%% of" % int(rules[key])
	return fallback


func _star2_sentence(rules: Dictionary) -> String:
	if _has_number(rules, "star2_lives"):
		return "Win with %d or more lives left for the second." % int(rules["star2_lives"])
	return "Win with most of your lives left for the second."


func _waves_sentence(rules: Dictionary) -> String:
	if _has_number(rules, "max_waves_running"):
		return "At most %d waves can be on the map at once." % int(rules["max_waves_running"])
	return "Only a few waves can be on the map at once."


func _has_number(rules: Dictionary, key: String) -> bool:
	return rules.has(key) and (rules[key] is int or rules[key] is float)
