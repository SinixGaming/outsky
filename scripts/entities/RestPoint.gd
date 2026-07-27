class_name RestPoint
extends Area2D
## Interact-triggered "bonfire": sets where the player wakes up on death,
## fully heals, and autosaves — standard rest-point convention, a cheap
## reuse of the already-existing SaveManager.save_game() call.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

## Which SpawnPoint in this room the player should arrive at when they
## respawn here after dying.
@export var rest_spawn_id: StringName = &"default"

@onready var sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false
var _player_ref: Player = null


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(20, 20), Color(0.9, 0.6, 0.2))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_ref = body


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_rest()


func _rest() -> void:
	GameState.set_rest_point(RoomManager.current_room_id, rest_spawn_id)
	if _player_ref:
		_player_ref.health.current_health = _player_ref.health.max_health
		# Soul/Vita pools aren't implemented yet (see Phase 2 plan note) —
		# full-heal covers Health only until they exist.
	SaveManager.save_game()
