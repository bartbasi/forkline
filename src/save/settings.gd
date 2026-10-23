# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Settings
extends RefCounted
## The player's settings, saved in settings.json (docs/ARCHITECTURE.md 3.5, 5.5).

const FORMAT: int = 1

var sound_on: bool = true


func to_data() -> Dictionary:
	return {"format": FORMAT, "sound": sound_on}


## Any bad field falls back to its default. Unknown keys are ignored.
static func from_data(data: Variant) -> Settings:
	var settings: Settings = Settings.new()
	if typeof(data) != TYPE_DICTIONARY:
		return settings
	var chk: DataCheck = DataCheck.new("settings.json")
	settings.sound_on = chk.boolean(data, "sound", "", true)
	return settings
