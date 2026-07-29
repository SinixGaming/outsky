class_name PlayerCamera
extends Camera2D
## Replaces the plain Camera2D on Player.tscn. Uses Godot's built-in
## drag-margin + limit system for "dynamic scroll" rooms (the engine's own
## default drag margin, 0.2, already matches the "~1/5 from screen edge"
## spec) rather than a hand-rolled follow script. Configured per-room by
## RoomManager.change_room() right after the new room is instantiated.

## Lower = more world visible = player reads smaller on screen. Applies to
## open/outdoor rooms only ("fixed"/"boss_arena" rooms like the house use
## their own auto-fit or explicit sizing instead).
@export var dynamic_scroll_zoom: float = 2.75
@export var smoothing_speed: float = 8.0
## Character apparent size is controlled by camera zoom, not sprite scale —
## this is the floor on that. boss_arena's whole point is "zoom out until
## the entire room fits," which for a large room means zooming out until
## the character reads as a speck. If the natural fit would go below this,
## we clamp to min_zoom instead and let the room not fully fit — at that
## point configure() falls back to dynamic-scroll-style panning so the
## rest of the room is still reachable, just not all visible at once.
@export var min_zoom: float = 1.2
## Fraction of the screen (from each edge) the player can roam before the
## camera starts scrolling. Lowered from the engine default of 0.2 (dead
## zone = central 60% of screen) to 0.1 (dead zone = central 80%) so
## scrolling kicks in sooner — there's less room to see what's ahead near
## the edges otherwise, per playtest feedback.
@export var drag_margin: float = 0.1


## render_scale mirrors Room.render_scale — a room rendered at render_scale=2
## has its SubViewport's internal resolution halved (then upscaled back by
## the container), so a raw fit-zoom computed against that shrunk viewport
## reads as half of what actually ends up on screen. min_zoom comparisons
## below correct for that so they compare apples to apples regardless of a
## room's render_scale.
func configure(mode: String, bounds: Rect2, render_scale: int = 1) -> void:
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
			top_level = true
			global_position = bounds.get_center()
			if _auto_fit_zoom(bounds, render_scale):
				# Whole room fits at a readable zoom — classic static,
				# fully-framed arena camera.
				drag_horizontal_enabled = false
				drag_vertical_enabled = false
				position_smoothing_enabled = false
			else:
				# Room is too large to fit without the character shrinking
				# past min_zoom — pan within it instead, same as
				# dynamic_scroll, rather than silently rendering it too
				# small or leaving parts of it permanently off-screen.
				top_level = false
				position = Vector2.ZERO
				drag_horizontal_enabled = true
				drag_vertical_enabled = true
				drag_left_margin = drag_margin
				drag_top_margin = drag_margin
				drag_right_margin = drag_margin
				drag_bottom_margin = drag_margin
				position_smoothing_enabled = true
				position_smoothing_speed = smoothing_speed
		_:
			push_warning("PlayerCamera: unknown camera_mode '%s'" % mode)


## Zoom so camera_bounds exactly fills the current viewport — "frame the
## whole arena" — unless that would drop below min_zoom on screen (the room
## is too large relative to the character), in which case zoom clamps and
## this returns false so configure() can fall back to panning instead.
## Returns true if the room fits entirely at a readable zoom.
func _auto_fit_zoom(bounds: Rect2, render_scale: int) -> bool:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		zoom = Vector2.ONE
		return true
	var scale_factor: float = max(1, render_scale)
	var fit_zoom: float = min(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	var apparent_zoom: float = fit_zoom * scale_factor
	if apparent_zoom >= min_zoom:
		zoom = Vector2(fit_zoom, fit_zoom)
		return true
	zoom = Vector2(min_zoom / scale_factor, min_zoom / scale_factor)
	return false
