# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PausePanel
extends Modal
## The Pause menu (playbook 6.4): Resume, Info, Settings, back to the menu (the
## game stays saved), abandon (after a confirm), and a quiet Buy me a coffee
## row at the bottom. The back button resumes, or cancels an open confirm.

signal resume_requested()
signal info_requested()
signal settings_requested()
## The player goes to the menu. The game stays saved.
signal leave_requested()
## The player confirmed that this game ends now.
signal abandon_confirmed()

var _confirm: ConfirmDialog = null
var _window_size: Vector2 = Vector2.ZERO
var _safe: Rect2 = Rect2()


func _init() -> void:
	super("Paused")
	var resume: TapButton = UiKit.button("Resume", &"PrimaryButton")
	resume.tapped.connect(_resume)
	body.add_child(resume)
	var info: TapButton = UiKit.button("Info")
	info.tapped.connect(func() -> void: info_requested.emit())
	body.add_child(info)
	var settings: TapButton = UiKit.button("Settings")
	settings.tapped.connect(func() -> void: settings_requested.emit())
	body.add_child(settings)
	var leave: TapButton = UiKit.button("Back to menu")
	leave.tapped.connect(func() -> void: leave_requested.emit())
	body.add_child(leave)
	var abandon: TapButton = UiKit.button("Abandon")
	abandon.tapped.connect(_ask_abandon)
	body.add_child(abandon)
	body.add_child(CoffeeButton.new())


func apply_layout(window_size: Vector2, safe: Rect2) -> void:
	super(window_size, safe)
	_window_size = window_size
	_safe = safe
	if _confirm != null:
		_confirm.apply_layout(window_size, safe)


func request_close() -> void:
	if _confirm != null:
		_confirm.request_close()
	else:
		_resume()


## True while the abandon question is open.
func confirm_open() -> bool:
	return _confirm != null


func _resume() -> void:
	resume_requested.emit()
	closed.emit()


func _ask_abandon() -> void:
	if _confirm != null:
		return
	_confirm = ConfirmDialog.new("Abandon?", "This game ends now and cannot be resumed.", "Abandon", "Keep playing")
	_confirm.confirmed.connect(func() -> void: abandon_confirmed.emit())
	_confirm.closed.connect(_confirm_closed)
	add_child(_confirm)
	if _window_size.x > 0.0:
		_confirm.apply_layout(_window_size, _safe)


func _confirm_closed() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
