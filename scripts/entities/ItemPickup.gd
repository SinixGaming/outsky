class_name ItemPickup
extends Area2D
## A ground item. Never authored directly in a room .tscn — always spawned
## at runtime, either by Room replaying WorldMemory on room load, or by
## whatever creates a fresh drop (e.g. Enemy loot). setup() never writes to
## WorldMemory itself — the caller is responsible for that, so replay never
## double-records and fresh drops record exactly once.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@onready var sprite: Sprite2D = $Sprite2D

var room_id: StringName
var item_uid: StringName
var item_id: StringName
var count: int = 1


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(10, 10), Color(0.95, 0.85, 0.2))
	body_entered.connect(_on_body_entered)


func setup(p_room_id: StringName, p_item_uid: StringName, p_item_id: StringName, p_count: int) -> void:
	room_id = p_room_id
	item_uid = p_item_uid
	item_id = p_item_id
	count = p_count


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	GameState.add_item(item_id, count)
	WorldMemory.remove_drop(room_id, item_uid)
	EventBus.item_collected.emit(room_id, item_uid)
	queue_free()
