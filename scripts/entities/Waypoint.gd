class_name Waypoint
extends Area2D
## Interact-triggered sign. Records discovery permanently and emits a
## signal for a future travel-menu UI — the menu itself is a content/UI
## follow-up, not part of this pass.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var waypoint_id: StringName = &""

@onready var sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(16, 32), Color(0.7, 0.75, 0.95))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		GameState.record_waypoint_discovered(String(waypoint_id))
		EventBus.waypoint_interacted.emit(waypoint_id)
