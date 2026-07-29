extends Node
## Owns the SubViewport that the game world renders into, and the
## SubViewportContainer that displays it. Godot does not allow manually
## setting SubViewport.size while its SubViewportContainer has
## stretch=true (the container drives the viewport's size, not the other
## way around) — so per-room "resolution" is expressed as a target aspect
## ratio (container sized/centered to match it, producing letterbox bars
## against the real window) plus an integer render_scale applied via
## SubViewportContainer.stretch_shrink, which IS safe to change at
## runtime and is what actually gives the render-cost saving on top of
## the visual effect.

var _container: SubViewportContainer = null
var _viewport: SubViewport = null
var _aspect_ratio: Vector2 = Vector2(16, 9)


func register(container: SubViewportContainer, viewport: SubViewport) -> void:
	_container = container
	_viewport = viewport
	_container.stretch = true
	if not get_tree().root.size_changed.is_connected(_update_container_rect):
		get_tree().root.size_changed.connect(_update_container_rect)
	_update_container_rect()


func set_room_display(aspect_ratio: Vector2, render_scale: int = 1) -> void:
	if _container == null:
		return
	if aspect_ratio.x > 0.0 and aspect_ratio.y > 0.0:
		_aspect_ratio = aspect_ratio
	_container.stretch_shrink = max(1, render_scale)
	_update_container_rect()


## Centers the container and sizes it to the room's target aspect ratio
## within the real window — whatever space is left over on the shorter
## axis becomes the black letterbox bars. stretch=true then makes Godot
## resize the SubViewport to match this container size automatically.
func _update_container_rect() -> void:
	if _container == null:
		return
	var window_size := Vector2(get_tree().root.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var target_ratio: float = _aspect_ratio.x / _aspect_ratio.y
	var window_ratio: float = window_size.x / window_size.y

	var display_size: Vector2
	if window_ratio > target_ratio:
		display_size = Vector2(window_size.y * target_ratio, window_size.y)
	else:
		display_size = Vector2(window_size.x, window_size.x / target_ratio)

	_container.custom_minimum_size = display_size
	_container.size = display_size
	_container.position = (window_size - display_size) / 2.0
