# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Checks the slice palette's contrast ratios (WCAG 2 formula).
## Text pairs need 4.5:1. Graphic pairs (icons, outlines, the route line,
## build pads) need 3:1. Exits 1 if any pair fails.
##
## Run from the repo root:
##     godot --headless --path . --script res://prototypes/theme/contrast.gd

const P: GDScript = preload("res://prototypes/theme/palette.gd")
const TEXT_MIN: float = 4.5
const GRAPHIC_MIN: float = 3.0


func _initialize() -> void:
	var failed: int = 0
	print("Text pairs (need %.1f:1)" % TEXT_MIN)
	for pair: Array in _text_pairs():
		failed += _check(pair, TEXT_MIN)
	print("Graphic pairs (need %.1f:1)" % GRAPHIC_MIN)
	for pair: Array in _graphic_pairs():
		failed += _check(pair, GRAPHIC_MIN)
	print("%d failing pairs." % failed)
	quit(1 if failed > 0 else 0)


func _text_pairs() -> Array:
	return [
		["TEXT_LIGHT on PANEL", "HUD numbers, hint line, toasts", P.TEXT_LIGHT, P.PANEL],
		["TEXT_LIGHT on PANEL_RAISED", "pause, speed and font buttons", P.TEXT_LIGHT, P.PANEL_RAISED],
		["TEXT_DARK on HONEY", "Start wave button", P.TEXT_DARK, P.HONEY],
		["TEXT_DARK on CARD", "tower card names", P.TEXT_DARK, P.CARD],
		["TEXT_MUTED on CARD", "tower card costs", P.TEXT_MUTED, P.CARD],
		["TEXT_DARK on CARD_DIM", "card name when gold is short", P.TEXT_DARK, P.CARD_DIM],
		["TEXT_MUTED on CARD_DIM", "card cost when gold is short", P.TEXT_MUTED, P.CARD_DIM],
		["TEXT_LIGHT on SKY_TOP", "titles on the night sky", P.TEXT_LIGHT, P.SKY_TOP],
		["COIN on INK_LINE", "floating +gold, drawn with an ink outline", P.COIN, P.INK_LINE],
		["TEXT_LIGHT on INK_LINE", "map labels with an ink outline", P.TEXT_LIGHT, P.INK_LINE],
	]


func _graphic_pairs() -> Array:
	return [
		["ROAD on MEADOW", "road against grass", P.ROAD, P.MEADOW],
		["INK_LINE on ROAD", "creature and gate outlines on the road", P.INK_LINE, P.ROAD],
		["INK_LINE on PAD", "tower outlines on their build pad", P.INK_LINE, P.PAD],
		["PLASTER on MEADOW", "cottage walls against grass", P.PLASTER, P.MEADOW],
		["INK_LINE on MEADOW_LIGHT", "outlines on the lightest grass", P.INK_LINE, P.MEADOW_LIGHT],
		["ROUTE on INK_LINE", "route dash core inside its ink casing", P.ROUTE, P.INK_LINE],
		["PAD on MEADOW", "empty build pad on grass", P.PAD, P.MEADOW],
		["HEART on PANEL", "lives icon", P.HEART, P.PANEL],
		["COIN on PANEL", "gold icon", P.COIN, P.PANEL],
		["MOON on PANEL", "wave icon", P.MOON, P.PANEL],
		["HONEY on PANEL", "Start wave button edge", P.HONEY, P.PANEL],
		["CARD on PANEL", "tower card edge", P.CARD, P.PANEL],
		["LANTERN on INK_LINE", "lantern windows in their frames", P.LANTERN, P.INK_LINE],
		["HP_FILL on HP_BACK", "creature health bar", P.HP_FILL, P.HP_BACK],
	]


func _check(pair: Array, minimum: float) -> int:
	var fg: Color = pair[2]
	var bg: Color = pair[3]
	var ratio: float = contrast(fg, bg)
	var ok: bool = ratio >= minimum
	print("  %s  %5.2f:1  %-28s #%s on #%s  (%s)" % ["ok  " if ok else "FAIL", ratio, pair[0], fg.to_html(false), bg.to_html(false), pair[1]])
	return 0 if ok else 1


static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


static func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
