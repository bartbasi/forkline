# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends "res://tests/base_test.gd"
## IconTex: the icons are cheap to build, are drawn where they should be, and every
## one the screens ask for is built when the app starts (a first wave must not pay
## for an icon). The time limit is 20 ms for one first build. On the PC the slowest
## icon takes about 8 ms in this run. The old pixel by pixel drawing took 26 to 95 ms,
## so the limit catches a return to it and leaves room for a busy machine.

const KINDS: Array[StringName] = [&"cup", &"gear", &"back", &"lock", &"check", &"arrow", &"close", &"pause", &"play"]
const LIMIT_MS: float = 20.0


## A size that no screen uses, so the first build really happens in this test.
func test_first_build_of_every_kind_is_fast() -> void:
	for kind: StringName in KINDS:
		for px: int in [57, 73]:
			var start: int = Time.get_ticks_usec()
			var tex: ImageTexture = IconTex.make(kind, px)
			var ms: float = float(Time.get_ticks_usec() - start) / 1000.0
			assert_true(ms < LIMIT_MS, "%s at %d px took %.1f ms" % [kind, px, ms])
			assert_eq(tex.get_width(), px)
			assert_eq(tex.get_height(), px)


func test_a_second_call_gives_the_same_texture() -> void:
	assert_true(IconTex.make(&"lock", 56) == IconTex.make(&"lock", 56))


func test_prewarm_builds_every_used_icon() -> void:
	IconTex.prewarm()
	for pair: Array in IconTex.USED_ICONS:
		assert_true(IconTex.is_built(pair[0] as StringName, int(pair[1])), "%s %s" % [pair[0], pair[1]])


func test_the_app_builds_the_icons_before_any_screen_needs_them() -> void:
	var made: App = App.new()
	made.build()
	for pair: Array in IconTex.USED_ICONS:
		assert_true(IconTex.is_built(pair[0] as StringName, int(pair[1])))
	made.free()


## Every `IconTex.make(&"kind", size)` and `icon_button(&"kind")` in src/ui/ is in the list
## that is built ahead of time.
func test_every_icon_the_code_asks_for_is_prebuilt() -> void:
	var make_call: RegEx = RegEx.create_from_string("IconTex\\.make\\(&\"(\\w+)\",\\s*(\\d+)\\)")
	var button_call: RegEx = RegEx.create_from_string("icon_button\\(&\"(\\w+)\"\\)")
	var found: int = 0
	for name: String in DirAccess.get_files_at("res://src/ui"):
		if not name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://src/ui/" + name)
		for hit: RegExMatch in make_call.search_all(text):
			found += 1
			assert_true(_listed(StringName(hit.get_string(1)), int(hit.get_string(2))), "%s asks for %s %s" % [name, hit.get_string(1), hit.get_string(2)])
		for hit: RegExMatch in button_call.search_all(text):
			found += 1
			assert_true(_listed(StringName(hit.get_string(1)), 72), "%s icon_button %s" % [name, hit.get_string(1)])
	assert_true(found > 15, "the scan found the calls")
	assert_true(_listed(&"cup", CoffeeButton.ICON_PX))


func _listed(kind: StringName, px: int) -> bool:
	for pair: Array in IconTex.USED_ICONS:
		if pair[0] == kind and int(pair[1]) == px:
			return true
	return false


## The shapes are where they should be: solid inside, clear outside, a hole in the lock.
func test_the_shapes_are_where_they_should_be() -> void:
	var lock: Image = IconTex.make(&"lock", 64).get_image()
	assert_true(lock.get_pixel(32, 50).a > 0.99, "lock body")
	assert_true(lock.get_pixel(32, 41).a < 0.01, "keyhole is clear")
	assert_true(lock.get_pixel(2, 2).a < 0.01, "corner is clear")
	assert_true(lock.get_pixel(32, 12).a > 0.99, "shackle top")
	assert_true(lock.get_pixel(32, 24).a < 0.01, "inside the shackle is clear")
	var pause: Image = IconTex.make(&"pause", 64).get_image()
	assert_true(pause.get_pixel(22, 32).a > 0.99, "left bar")
	assert_true(pause.get_pixel(32, 32).a < 0.01, "gap")
	var gear: Image = IconTex.make(&"gear", 64).get_image()
	assert_true(gear.get_pixel(32, 32).a < 0.01, "gear hole")
	assert_true(gear.get_pixel(32, 12).a > 0.99, "gear ring")
	assert_true(gear.get_pixel(32, 3).a > 0.99, "tooth at the top")
	assert_true(gear.get_pixel(2, 2).a < 0.01, "gear corner")
	var play: Image = IconTex.make(&"play", 64).get_image()
	assert_true(play.get_pixel(24, 32).a > 0.99, "triangle")
	assert_true(play.get_pixel(24, 8).a < 0.01, "above the triangle")
	# Every icon draws something, white, and leaves the corner clear.
	for kind: StringName in KINDS:
		var image: Image = IconTex.make(kind, 64).get_image()
		var solid: int = 0
		for y: int in 64:
			for x: int in 64:
				var c: Color = image.get_pixel(x, y)
				assert_true(c.r > 0.99 and c.g > 0.99 and c.b > 0.99, "%s is white" % kind)
				if c.a > 0.5:
					solid += 1
		assert_true(solid > 200 and solid < 3000, "%s covers a sensible area (%d)" % [kind, solid])
