# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## A drawing layer for the slice. Its owner sets `painter`, which draws onto
## this node in _draw(). Prototype only.

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
