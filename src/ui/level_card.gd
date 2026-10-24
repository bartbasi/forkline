# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelCard
extends PageFrame
## The level card (RULES 10.5, 12.4): the name, the waves, the gates, the three star
## lines with the stars earned, the hint, and the choice of Normal or Relaxed. Normal
## is always chosen when the card opens; the card never remembers Relaxed (Bart, hard
## stop A). A level with a saved game offers Resume first and says which difficulty
## that game is on; the choice below it is for starting over.

## Start the level. `relaxed` is the choice on the card.
signal play_requested(relaxed: bool)
## Go back to the saved game of this level.
signal resume_requested()

var level_id: StringName
var relaxed: bool = false
var play_button: TapButton
var resume_button: TapButton
var saved_label: Label
var normal_button: TapButton
var relaxed_button: TapButton
var difficulty_label: Label
var star_rows: Array[HBoxContainer] = []
var star_sentences: Array[Label] = []
var star_icons: Array[StarIcon] = []
var hint_label: Label
var waves_label: Label
var gates_label: Label

var _normal_text: String = ""
var _relaxed_text: String = ""


## `saved` is true when this level has a saved game, and `saved_relaxed` is that game's difficulty.
func _init(game: GameData, progress: Progress, id: StringName, saved: bool, saved_relaxed: bool = false) -> void:
	var level: LevelData = game.levels[id]
	super("Level %s" % CampaignText.number(game, id))
	level_id = id
	var name_label: Label = UiKit.label(level.name, &"TitleLabel")
	column.add_child(name_label)
	column.add_child(_facts(level))
	column.add_child(_stars(game, progress, level))
	if not level.hint_text.is_empty():
		column.add_child(_hint(level))
	column.add_child(_difficulty(game, level, saved))
	if saved:
		saved_label = UiKit.label("Your saved game is on %s." % ("Relaxed" if saved_relaxed else "Normal"), &"Label")
		column.add_child(saved_label)
		resume_button = UiKit.button("Resume", &"PrimaryButton")
		resume_button.tapped.connect(func() -> void: resume_requested.emit())
		column.add_child(resume_button)
		play_button = UiKit.button("Start over")
	else:
		play_button = UiKit.button("Play", &"PrimaryButton")
	play_button.custom_minimum_size.y = 200.0
	play_button.tapped.connect(func() -> void: play_requested.emit(relaxed))
	column.add_child(play_button)


## Chooses Normal or Relaxed, as a tap on its button does.
func choose(is_relaxed: bool) -> void:
	relaxed = is_relaxed
	BattlePanel.mark_chosen(normal_button, not relaxed)
	BattlePanel.mark_chosen(relaxed_button, relaxed)
	difficulty_label.text = _relaxed_text if relaxed else _normal_text


func _facts(level: LevelData) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	waves_label = UiKit.heading("%d waves" % level.waves.size())
	waves_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(waves_label)
	gates_label = UiKit.heading(CampaignText.gates_text(level.gates))
	gates_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(gates_label)
	return row


func _stars(game: GameData, progress: Progress, level: LevelData) -> Control:
	var box: VBoxContainer = UiKit.section()
	var earned: int = progress.levels.get(level.id, 0)
	box.add_child(UiKit.heading("Stars: %d of 3" % StarText.count(earned)))
	var lines: PackedStringArray = StarText.lines(level, game.catalog)
	for i: int in 3:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 18)
		var got: bool = (earned >> i) & 1 == 1
		var icon: StarIcon = StarIcon.new(64.0, got)
		star_icons.append(icon)
		row.add_child(icon)
		var sentence: Label = UiKit.label(lines[i])
		sentence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sentence.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star_sentences.append(sentence)
		row.add_child(sentence)
		var state: Label = UiKit.label("Earned" if got else "Not yet", &"Label" if got else &"SoftLabel")
		state.autowrap_mode = TextServer.AUTOWRAP_OFF
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state)
		star_rows.append(row)
		box.add_child(row)
	return box.get_parent() as Control


func _hint(level: LevelData) -> Control:
	var box: VBoxContainer = UiKit.section()
	box.add_child(UiKit.heading("Hint"))
	hint_label = UiKit.label(level.hint_text)
	box.add_child(hint_label)
	return box.get_parent() as Control


func _difficulty(game: GameData, level: LevelData, saved: bool) -> Control:
	var box: VBoxContainer = UiKit.section()
	box.add_child(UiKit.heading("Difficulty if you start over" if saved else "Difficulty"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	normal_button = UiKit.button("Normal")
	normal_button.tapped.connect(choose.bind(false))
	row.add_child(normal_button)
	relaxed_button = UiKit.button("Relaxed")
	relaxed_button.tapped.connect(choose.bind(true))
	row.add_child(relaxed_button)
	box.add_child(row)
	var normal: Battle = Battle.create(level, game.catalog, false, [] as Array[Dictionary])
	var easy: Battle = Battle.create(level, game.catalog, true, [] as Array[Dictionary])
	_normal_text = "Normal: %d lives and %d gold. All three stars." % [normal.lives, normal.gold]
	_relaxed_text = "Relaxed: %d lives and %d gold. Only the first star." % [easy.lives, easy.gold]
	difficulty_label = UiKit.label(_normal_text, &"SoftLabel")
	box.add_child(difficulty_label)
	choose(false)
	return box.get_parent() as Control
