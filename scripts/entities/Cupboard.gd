class_name Cupboard
extends Area2D
## Interact-triggered chargen. Doesn't do the work itself — emits
## EventBus.stat_allocation_requested and lets Main.gd react (same
## "emit and let something else react" precedent as Waypoint.gd), which
## instantiates the stat allocation popup and pauses the game.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var placeholder_size: Vector2i = Vector2i(28, 40)
@export var placeholder_color: Color = Color(0.45, 0.3, 0.15)

@onready var sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false
var _allocated: bool = false


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(placeholder_size, placeholder_color)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if _allocated:
		return
	if _player_in_range and event.is_action_pressed("interact"):
		_allocated = true
		EventBus.stat_allocation_requested.emit()
