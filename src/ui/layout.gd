# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Layout
extends RefCounted
## Which layout to use, and where the safe area is (docs/ARCHITECTURE.md 7.4).
##
## The layout is a pure function of the window size. It never reads the
## orientation of the phone. All sizes are logical pixels of the 1080 wide base.

## Landscape layout when the window is less than 1.5 times taller than wide.
const LANDSCAPE_BELOW: float = 1.5
## At least 48 dp on every screen in section 7.4.
const MIN_TOUCH: float = 160.0
## Outer padding of every screen, inside the safe area.
const PAD: float = 36.0
## Text pages never get wider than this, so lines stay readable.
const CONTENT_MAX: float = 1100.0


## True when the window is close to square or wider than tall.
static func is_landscape(window_size: Vector2) -> bool:
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return false
	return window_size.y < LANDSCAPE_BELOW * window_size.x


## The display safe area in viewport coordinates. The whole viewport when the
## display reports nothing useful (desktop windows, headless runs, SubViewports).
static func safe_rect(viewport: Viewport) -> Rect2:
	var full: Vector2 = viewport.get_visible_rect().size
	var window: Window = viewport as Window
	if window == null:
		return Rect2(Vector2.ZERO, full)
	var id: int = window.get_window_id()
	return safe_in_viewport(
		full,
		Vector2(DisplayServer.window_get_size(id)),
		Vector2(DisplayServer.window_get_position(id)),
		Rect2(DisplayServer.get_display_safe_area()))


## Maps a safe area given in screen pixels into viewport coordinates.
## `window_px` and `window_pos` describe the window on the screen.
static func safe_in_viewport(full: Vector2, window_px: Vector2, window_pos: Vector2, safe_screen: Rect2) -> Rect2:
	var whole: Rect2 = Rect2(Vector2.ZERO, full)
	if window_px.x <= 0.0 or window_px.y <= 0.0 or safe_screen.size.x <= 0.0 or safe_screen.size.y <= 0.0:
		return whole
	var k: Vector2 = Vector2(full.x / window_px.x, full.y / window_px.y)
	var local: Rect2 = Rect2((safe_screen.position - window_pos) * k, safe_screen.size * k)
	var clipped: Rect2 = whole.intersection(local)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return whole
	return clipped


## The width a text page may use: the safe width, less padding, capped.
static func content_width(window_width: float, safe: Rect2) -> float:
	return minf(CONTENT_MAX, maxf(MIN_TOUCH, minf(window_width, safe.size.x) - 2.0 * PAD))
