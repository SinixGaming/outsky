extends Node
## Owns the SubViewport that the game world renders into, and the
## SubViewportContainer that displays it. Setting a smaller/larger
## viewport size per room type is what gives both the letterbox visual
## effect and a genuine render-cost saving (the render target itself
## shrinks, not just a visual crop).

var _container: SubViewportContainer = null
var _viewport: SubViewport = null


func register(container: SubViewportContainer, viewport: SubViewport) -> void:
	_container = container
	_viewport = viewport
	if not get_tree().root.size_changed.is_connected(_update_container_rect):
		get_tree().root.size_changed.connect(_update_container_rect)
	_update_container_rect()


func set_resolution(size: Vector2i) -> void:
	if _viewport == null or size.x <= 0 or size.y <= 0:
		return
	_viewport.size = size
	_update_container_rect()


## Centers the container and scales it (via SubViewportContainer.stretch)
## to fit the real window at the room's target aspect ratio — whatever
## space is left over on the shorter axis becomes the black letterbox bars.
func _update_container_rect() -> void:
	if _container == null or _viewport == null:
		return
	var window_size := Vector2(get_tree().root.size)
	var target_size := Vector2(_viewport.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return

	var display_scale: float = min(window_size.x / target_size.x, window_size.y / target_size.y)
	var display_size := target_size * display_scale

	_container.custom_minimum_size = display_size
	_container.size = display_size
	_container.position = (window_size - display_size) / 2.0
