class_name Chest
extends Area2D
## Never respawns once opened, ever — same permanent-flag self-check
## pattern as Enemy.gd's WorldMemory check, but against GameState's
## permanent opened_chests store instead of WorldMemory's session-scoped one.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

## Must be globally unique across the whole game, e.g. "inithia_prairie_01_chest_a".
@export var chest_uid: String = ""
@export var gold_reward: int = 10
@export var item_id: StringName = &""
@export var item_count: int = 1

@onready var sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false


func _ready() -> void:
	if GameState.is_chest_opened(chest_uid):
		queue_free()
		return
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(24, 20), Color(0.6, 0.42, 0.15))
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
		_open()


func _open() -> void:
	GameState.mark_chest_opened(chest_uid)
	if gold_reward > 0:
		GameState.add_gold(gold_reward)
	if item_id != &"":
		GameState.add_item(item_id, item_count)
	queue_free()
