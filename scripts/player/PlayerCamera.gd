class_name PlayerCamera
extends Camera2D
## Replaces the plain Camera2D on Player.tscn. Uses Godot's built-in
## drag-margin + limit system for "dynamic scroll" rooms (the engine's own
## default drag margin, 0.2, already matches the "~1/5 from screen edge"
## spec) rather than a hand-rolled follow script. Configured per-room by
## RoomManager.change_room() right after the new room is instantiated.

@export var dynamic_scroll_zoom: float = 2.0
@export var smoothing_speed: float = 8.0
@export var drag_margin: float = 0.2


func configure(mode: String, bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)

	match mode:
		"dynamic_scroll":
			# Stays a normal child of Player — its global position tracks
			# the player every frame, and the drag margins below turn that
			# into a dead-zone-until-edge scroll instead of a 1:1 follow.
			top_level = false
			position = Vector2.ZERO
			zoom = Vector2(dynamic_scroll_zoom, dynamic_scroll_zoom)
			drag_horizontal_enabled = true
			drag_vertical_enabled = true
			drag_left_margin = drag_margin
			drag_top_margin = drag_margin
			drag_right_margin = drag_margin
			drag_bottom_margin = drag_margin
			position_smoothing_enabled = true
			position_smoothing_speed = smoothing_speed
		"fixed":
			# top_level decouples the camera from the player's transform so
			# it can be pinned in place — small interiors, doors at the
			# screen edge (RoomTransitionZone) keep working unchanged.
			drag_horizontal_enabled = false
			drag_vertical_enabled = false
			position_smoothing_enabled = false
			zoom = Vector2(dynamic_scroll_zoom, dynamic_scroll_zoom)
			top_level = true
			global_position = bounds.get_center()
		"boss_arena":
			drag_horizontal_enabled = false
			drag_vertical_enabled = false
			position_smoothing_enabled = false
			top_level = true
			global_position = bounds.get_center()
			_auto_fit_zoom(bounds)
		_:
			push_warning("PlayerCamera: unknown camera_mode '%s'" % mode)


## Zoom so camera_bounds exactly fills the current viewport — guarantees
## "frame the whole arena" regardless of authored arena size, and as a
## side effect keeps the player small relative to the screen, as requested.
func _auto_fit_zoom(bounds: Rect2) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		zoom = Vector2.ONE
		return
	var fit_zoom: float = min(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	zoom = Vector2(fit_zoom, fit_zoom)
