# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## AudioService: events and UI sounds start voices, the caps hold, and the
## toggle silences everything.

const EVENT_KINDS: Array[StringName] = [
	&"wave_started", &"spawned", &"fired", &"popped", &"defeated", &"healed",
	&"leaked", &"gate_broken", &"wave_cleared", &"build_started", &"built",
	&"upgraded", &"sold", &"gate_placed", &"gate_removed", &"won", &"lost",
]

var service: AudioService = null


func before_each() -> void:
	# The runner starts tests before the scene tree is running, so the service
	# is used outside the tree. Voice bookkeeping and the caps run the same
	# there; only the engine's play() call is skipped.
	service = AudioService.new()
	service.wait_until_ready()


func after_each() -> void:
	service.free()
	service = null


func _event(kind: StringName) -> Dictionary:
	return {"kind": kind, "id": 7, "tower": Vector2i(2, 3), "cell": Vector2i(1, 1)}


func _events(kind: StringName, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in count:
		out.append(_event(kind))
	return out


func _playing_players() -> int:
	var count: int = 0
	for child: Node in service.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			count += 1
	return count


func test_every_sound_is_built() -> void:
	assert_true(service.is_ready())
	for sound: StringName in SoundBank.EFFECTS:
		assert_not_null(service._bank.stream(sound), "%s missing" % sound)
	for track: StringName in SoundBank.TRACKS:
		assert_not_null(service._bank.stream(track), "%s missing" % track)


func test_every_event_kind_starts_a_voice() -> void:
	for kind: StringName in EVENT_KINDS:
		service.set_enabled(false)
		service.set_enabled(true)
		service.play_events(_events(kind, 1))
		var sound: StringName = AudioService.EVENT_SOUNDS[kind]
		assert_eq(service.voice_count(sound), 1, "%s made no sound" % kind)


func test_every_ui_sound_starts_a_voice() -> void:
	for sound: StringName in AudioService.UI_SOUNDS:
		service.play_ui(sound)
		assert_eq(service.voice_count(sound), 1, "%s made no sound" % sound)


func test_unknown_events_and_ui_sounds_are_ignored() -> void:
	var hostile: Array[Dictionary] = [
		{}, {"kind": 5}, {"kind": &"no_such_kind"}, {"kind": "also_nothing"},
		{"kind": &"fired"}, {"kind": &"fired", "tower": "x"}, {"kind": &"defeated", "id": "x"},
	]
	service.play_events(hostile)
	# Only the fired and defeated events are real kinds, so at most two sounds start.
	assert_true(service.voice_count() <= 2)
	service.play_ui(&"no_such_ui")
	service.play_ui(&"fired")
	assert_eq(service.voice_count(&"star"), 0)


func test_fifty_of_one_event_in_one_frame_hold_the_caps() -> void:
	for kind: StringName in EVENT_KINDS:
		service.set_enabled(false)
		service.set_enabled(true)
		service.play_events(_events(kind, 50))
		var sound: StringName = AudioService.EVENT_SOUNDS[kind]
		assert_true(service.voice_count(sound) >= 1, "%s: nothing played" % kind)
		assert_true(service.voice_count(sound) <= AudioService.MAX_SAME, "%s: %d voices" % [kind, service.voice_count(sound)])
		assert_true(service.voice_count() <= AudioService.VOICES, "%s: %d voices in all" % [kind, service.voice_count()])


func test_same_sound_cap_holds_over_time() -> void:
	# Spaced starts get past the gap, so only the cap of 3 can stop them.
	var gap: int = int(AudioService.GAP_MS[&"defeated"]) + 15
	var most: int = 0
	for i: int in 8:
		service.play_events(_events(&"defeated", 10))
		most = maxi(most, service.voice_count(&"defeated"))
		assert_true(service.voice_count(&"defeated") <= AudioService.MAX_SAME)
		OS.delay_msec(gap)
	assert_eq(most, AudioService.MAX_SAME, "the cap was never reached, so the test proved nothing")


func test_total_cap_holds_with_every_sound_at_once() -> void:
	var all: Array[Dictionary] = []
	for kind: StringName in EVENT_KINDS:
		all.append(_event(kind))
	var most: int = 0
	for round_index: int in 6:
		service.play_events(all)
		for sound: StringName in AudioService.UI_SOUNDS:
			service.play_ui(sound)
		most = maxi(most, service.voice_count())
		assert_true(service.voice_count() <= AudioService.VOICES)
		OS.delay_msec(130)
	assert_true(most > AudioService.MAX_SAME, "mixed sounds never stacked: %d" % most)


func test_the_big_sounds_still_play_when_voices_are_full() -> void:
	# Fill every voice with frequent sounds, then ask for a loss.
	for round_index: int in 8:
		service.play_events(_events(&"defeated", 3))
		service.play_events(_events(&"fired", 3))
		service.play_events(_events(&"spawned", 3))
		service.play_events(_events(&"popped", 3))
		service.play_events(_events(&"healed", 3))
		OS.delay_msec(70)
	service.play_events(_events(&"lost", 1))
	assert_eq(service.voice_count(&"lost"), 1)
	assert_true(service.voice_count() <= AudioService.VOICES)


func test_toggle_off_silences_everything() -> void:
	service.set_music(&"battle")
	service.play_events(_events(&"wave_cleared", 1))
	service.play_ui(&"tap")
	assert_true(service.voice_count() > 0)
	assert_true(service.is_music_playing())
	service.set_enabled(false)
	assert_false(service.is_enabled())
	assert_eq(service.voice_count(), 0)
	assert_false(service.is_music_playing())
	assert_eq(_playing_players(), 0, "a player is still playing")
	# New sounds, UI sounds and music stay silent while off.
	for kind: StringName in EVENT_KINDS:
		service.play_events(_events(kind, 5))
	for sound: StringName in AudioService.UI_SOUNDS:
		service.play_ui(sound)
	service.set_music(&"menu")
	assert_eq(service.voice_count(), 0)
	assert_eq(_playing_players(), 0)
	assert_false(service.is_music_playing())


func test_toggle_back_on_brings_the_music_back() -> void:
	service.set_music(&"battle")
	service.set_enabled(false)
	service.set_enabled(true)
	assert_eq(service.current_music(), &"battle")
	assert_true(service.is_music_playing())
	service.play_ui(&"tap")
	assert_eq(service.voice_count(&"tap"), 1)


func test_music_choice() -> void:
	service.set_music(&"menu")
	assert_eq(service.current_music(), &"menu")
	assert_true(service.is_music_playing())
	service.set_music(&"battle")
	assert_eq(service.current_music(), &"battle")
	service.set_music(&"")
	assert_eq(service.current_music(), &"")
	service.set_music(&"no_such_track")
	assert_eq(service.current_music(), &"")


func test_music_asked_before_the_streams_are_built_starts_when_ready() -> void:
	var early: AudioService = AudioService.new()
	early.set_music(&"battle")
	early.wait_until_ready()
	assert_true(early.is_music_playing())
	early.free()


func test_sounds_asked_before_they_are_built_are_skipped_not_fatal() -> void:
	var early: AudioService = AudioService.new()
	early.play_events(_events(&"won", 1))
	early.play_ui(&"star")
	early.wait_until_ready()
	assert_true(early.voice_count() <= 2)
	early.free()


func test_disabled_before_anything_else_stays_silent() -> void:
	var early: AudioService = AudioService.new()
	early.set_enabled(false)
	early.set_music(&"menu")
	early.wait_until_ready()
	early.play_ui(&"tap")
	early.play_events(_events(&"won", 1))
	assert_eq(early.current_music(), &"menu")
	assert_false(early.is_music_playing())
	assert_eq(early.voice_count(), 0)
	early.free()


func test_mixer_buses_exist_and_the_sfx_bus_has_a_limiter() -> void:
	var sfx: int = AudioServer.get_bus_index(AudioService.SFX_BUS)
	assert_true(sfx >= 0)
	assert_true(AudioServer.get_bus_index(AudioService.MUSIC_BUS) >= 0)
	assert_true(AudioServer.get_bus_effect(sfx, 0) is AudioEffectLimiter)
