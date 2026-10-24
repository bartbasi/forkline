# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## Runs last in tests/ui (files run in name order): frees the AudioService that the flow
## tests share, so the test run ends with nothing leaked.

const Fx: GDScript = preload("res://tests/ui/flow_fixtures.gd")


func test_the_shared_audio_service_is_freed() -> void:
	Fx.free_audio()
	assert_true(true)
