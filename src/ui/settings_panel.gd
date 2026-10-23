# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name SettingsPanel
extends Modal
## Settings: sound on or off, and a row that opens About (playbook 6.4).

signal sound_changed(on: bool)
signal about_requested()

var sound_on: bool = true
var sound_button: TapButton


func _init(initial_sound_on: bool) -> void:
	super("Settings")
	sound_on = initial_sound_on
	sound_button = UiKit.button("")
	sound_button.tapped.connect(_toggle_sound)
	body.add_child(sound_button)
	var about: TapButton = UiKit.button("About")
	about.tapped.connect(func() -> void: about_requested.emit())
	body.add_child(about)
	var done: TapButton = UiKit.button("Close", &"PrimaryButton")
	done.tapped.connect(request_close)
	body.add_child(done)
	_show_sound()


func _toggle_sound() -> void:
	sound_on = not sound_on
	_show_sound()
	sound_changed.emit(sound_on)


func _show_sound() -> void:
	sound_button.text = "Sound: On" if sound_on else "Sound: Off"
