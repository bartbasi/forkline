# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Palette
extends RefCounted
## Color tokens for the dusk storybook theme (docs/art/THEME.md).
##
## Warm is ours, cool is theirs: towers, lanterns and the HUD accents are warm,
## night creatures are cool. Everything that matters has an INK_LINE outline,
## so contrast never depends on a fill color. Text sits on an opaque panel or
## has an ink outline. The pairs at the bottom are checked by tests/theme/.

# Sky and far hills.
const SKY_TOP: Color = Color("1e1a3c")
const SKY_MID: Color = Color("4b3767")
const SKY_LOW: Color = Color("b8676d")
const SKY_GLOW: Color = Color("f0ad7c")
const MOON: Color = Color("fff1c9")
const STAR: Color = Color("fff6e0")
const HILL_FAR: Color = Color("4a4775")
const HILL_MID: Color = Color("35506b")
const HILL_NEAR: Color = Color("253e45")

# The map: meadow, roads, build spots, route lines.
const MEADOW: Color = Color("3f644b")
const MEADOW_LIGHT: Color = Color("52775a")
const MEADOW_DARK: Color = Color("33543f")
const ROAD: Color = Color("e2c18e")
const ROAD_EDGE: Color = Color("8a6548")
const ROAD_DOT: Color = Color("cba774")
const ROUTE: Color = Color("fff4cc")
const PAD: Color = Color("d0c6b3")
const PAD_EDGE: Color = Color("8c8274")
const THICKET: Color = Color("16122a")

# Buildings.
const LANTERN: Color = Color("ffc65c")
const LANTERN_CORE: Color = Color("fff3c2")
const GLOW: Color = Color("ffa94a")
const PLASTER: Color = Color("f1e2c4")
const PLASTER_SHADE: Color = Color("cdb796")
const TIMBER: Color = Color("6a4836")
const WOOD: Color = Color("94633f")
const ROOF_CLAY: Color = Color("b9573f")
const ROOF_SLATE: Color = Color("50607f")
const ROOF_MOSS: Color = Color("71844a")
const ROOF_PLUM: Color = Color("7c4b73")
const STONE: Color = Color("aaa192")
const STONE_DARK: Color = Color("7a7266")
const IRON: Color = Color("4b4f63")
const PUMPKIN: Color = Color("e8873a")
const JAM: Color = Color("a8325a")
const TREE: Color = Color("3d6450")
const TREE_DARK: Color = Color("2a4a3e")
const INK_LINE: Color = Color("211a2e")
const SMOKE: Color = Color("c9c0dc")
const SHADOW: Color = Color(0.05, 0.03, 0.1, 0.28)

# Night creatures and their sparkles.
const CREATURE_BASIC: Color = Color("8a93d8")
const CREATURE_FAST: Color = Color("62c8b3")
const CREATURE_ARMOR: Color = Color("8d97a8")
const CREATURE_ARMOR_SHELL: Color = Color("5f6880")
const CREATURE_SWARM: Color = Color("bf96e8")
const CREATURE_FLY: Color = Color("6fa8c9")
const CREATURE_BUBBLE: Color = Color("7fd3e3")
const CREATURE_PUFF: Color = Color("b9b4dc")
const CREATURE_MEND: Color = Color("7cbf9a")
const CREATURE_MEND_CAP: Color = Color("6b78c4")
const CREATURE_BRUTE: Color = Color("6d72b3")
const CREATURE_MOTH: Color = Color("8077ad")
const BOSS_SACK: Color = Color("9a8fcf")
const BOSS_SHELL: Color = Color("4c5470")
const BOSS_MOON: Color = Color("b9c6f4")
const BOSS_TUSK: Color = Color("7a80a8")
const BONE: Color = Color("efe6d2")
const EYE: Color = Color("f4fff6")
const SPARKLE: Color = Color("fff6d6")
const SPARKLE_LILAC: Color = Color("d5c2ff")
const FLOUR: Color = Color("e8f0ff")
const BUBBLE: Color = Color("dff6ff")

# Interface.
const PANEL: Color = Color("2a2140")
const PANEL_RAISED: Color = Color("3d3159")
const PANEL_HOVER: Color = Color("4a3d6b")
const PANEL_EDGE: Color = Color("8a79ad")
const CARD: Color = Color("f4e6cb")
const CARD_DIM: Color = Color("cfc3ad")
const TEXT_LIGHT: Color = Color("f7ebd3")
const TEXT_SOFT: Color = Color("c9bcd9")
const TEXT_DARK: Color = Color("2a2033")
const TEXT_MUTED: Color = Color("5a4760")
const HONEY: Color = Color("f2b544")
const HONEY_PRESSED: Color = Color("d99a2b")
const HEART: Color = Color("e8697d")
const COIN: Color = Color("ffd166")
const HP_BACK: Color = Color("2a2140")
const HP_FILL: Color = Color("a6e39a")


## Text pairs: [foreground token, background token, where it shows]. Each must
## reach 4.5:1. A token name is a constant above.
static func text_pairs() -> Array[PackedStringArray]:
	return [
		PackedStringArray(["TEXT_LIGHT", "PANEL", "HUD numbers, hints, panels, toasts"]),
		PackedStringArray(["TEXT_SOFT", "PANEL", "secondary text on panels"]),
		PackedStringArray(["TEXT_LIGHT", "PANEL_RAISED", "buttons"]),
		PackedStringArray(["TEXT_LIGHT", "PANEL_HOVER", "a button while pressed or hovered"]),
		PackedStringArray(["TEXT_SOFT", "PANEL_RAISED", "secondary text on buttons, a disabled button"]),
		PackedStringArray(["TEXT_DARK", "HONEY", "the primary button (Start wave, Play)"]),
		PackedStringArray(["TEXT_DARK", "HONEY_PRESSED", "the primary button while pressed"]),
		PackedStringArray(["TEXT_DARK", "CARD", "tower cards, info cards"]),
		PackedStringArray(["TEXT_MUTED", "CARD", "costs and small lines on cards"]),
		PackedStringArray(["TEXT_DARK", "CARD_DIM", "a card when gold is short"]),
		PackedStringArray(["TEXT_MUTED", "CARD_DIM", "a cost when gold is short"]),
		PackedStringArray(["TEXT_LIGHT", "SKY_TOP", "titles on the night sky"]),
		PackedStringArray(["TEXT_LIGHT", "INK_LINE", "map labels with an ink outline"]),
		PackedStringArray(["COIN", "INK_LINE", "floating gold with an ink outline"]),
		PackedStringArray(["HONEY", "PANEL", "highlighted numbers on panels"]),
		PackedStringArray(["CARD", "INK_LINE", "the wordmark letters in their ink outline"]),
	]


## Graphic pairs: icons, outlines, shapes against what they sit on. Each must
## reach 3:1.
static func graphic_pairs() -> Array[PackedStringArray]:
	return [
		PackedStringArray(["ROAD", "MEADOW", "road against grass"]),
		PackedStringArray(["ROAD_EDGE", "ROAD", "the road's border"]),
		PackedStringArray(["INK_LINE", "ROAD", "creature and gate outlines on the road"]),
		PackedStringArray(["INK_LINE", "PAD", "tower outlines on their build spot"]),
		PackedStringArray(["INK_LINE", "MEADOW_LIGHT", "outlines on the lightest grass"]),
		PackedStringArray(["PAD", "MEADOW", "an empty build spot on grass"]),
		PackedStringArray(["PLASTER", "MEADOW", "cottage walls against grass"]),
		PackedStringArray(["ROUTE", "INK_LINE", "route line core inside its ink casing"]),
		PackedStringArray(["INK_LINE", "ROUTE", "route line casing against its core"]),
		PackedStringArray(["ROUTE", "MEADOW", "a flyer's dotted line over grass"]),
		PackedStringArray(["HEART", "PANEL", "lives icon"]),
		PackedStringArray(["COIN", "PANEL", "gold icon"]),
		PackedStringArray(["MOON", "PANEL", "wave icon"]),
		PackedStringArray(["HONEY", "PANEL", "primary button edge, selection ring"]),
		PackedStringArray(["CARD", "PANEL", "tower card edge"]),
		PackedStringArray(["PANEL_EDGE", "PANEL", "panel border"]),
		PackedStringArray(["INK_LINE", "HONEY", "primary button border"]),
		PackedStringArray(["LANTERN", "INK_LINE", "lantern windows in their frames"]),
		PackedStringArray(["HP_FILL", "HP_BACK", "creature health bar"]),
		PackedStringArray(["BUBBLE", "INK_LINE", "a Bubbler's bubble ring in its casing"]),
		PackedStringArray(["FLOUR", "INK_LINE", "the drowsy mark in its casing"]),
		PackedStringArray(["HEART", "INK_LINE", "the refused gate cross in its casing"]),
		PackedStringArray(["TIMBER", "ROAD", "an open gate's arch and posts over the road"]),
		PackedStringArray(["EYE", "INK_LINE", "creature eyes"]),
		PackedStringArray(["TEXT_LIGHT", "PANEL_RAISED", "icons on buttons"]),
		PackedStringArray(["TEXT_DARK", "CARD", "tower silhouettes on cards"]),
	]


## The color of a token by name, or transparent black when there is none.
static func token(token_name: String) -> Color:
	var tokens: Dictionary = (Palette as Script).get_script_constant_map()
	var value: Variant = tokens.get(token_name, null)
	if value is Color:
		return value
	return Color(0.0, 0.0, 0.0, 0.0)


## WCAG 2 contrast ratio between two opaque colors, from 1 to 21.
static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## WCAG 2 relative luminance of an sRGB color.
static func luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


static func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
