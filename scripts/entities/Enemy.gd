class_name Enemy
extends CharacterBody2D
## Self-sufficient with respect to room memory: checks WorldMemory in its
## own _ready() and frees itself if already dead, and records its own
## death + loot drop + gold payout. Rooms need no bespoke code for this to
## work. _is_already_defeated()/_record_death() are overridden by Boss.gd
## to swap WorldMemory's session-scoped tracking for GameState's permanent
## defeated_bosses flag, without touching anything else here.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")
const ItemPickupScene := preload("res://scenes/entities/ItemPickup.tscn")

## Repeat kills of the same overworld enemy pay this fraction of gold_value
## (dungeon rooms are exempt — see Room.is_dungeon_room).
const REPEAT_KILL_GOLD_FRACTION := 0.25

## Must be unique within the room this enemy is placed in.
@export var spawn_uid: StringName = &""
@export var loot_item_id: StringName = &"small_potion"
@export var loot_count: int = 1
@export var gold_value: int = 5

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Health = $Health


func _ready() -> void:
	if _is_already_defeated():
		queue_free()
		return

	add_to_group("enemies")
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(18, 18), Color(0.85, 0.2, 0.2))
	health.died.connect(_on_died)


func take_damage(amount: int) -> void:
	health.take_damage(amount)


func _is_already_defeated() -> bool:
	return WorldMemory.is_dead(RoomManager.current_room_id, spawn_uid)


func _record_death() -> void:
	WorldMemory.record_death(RoomManager.current_room_id, spawn_uid)


func _on_died() -> void:
	var room_id := RoomManager.current_room_id
	_record_death()

	var item_uid := StringName("%s_loot" % spawn_uid)
	WorldMemory.record_drop(room_id, item_uid, loot_item_id, loot_count, global_position)

	var pickup: Node2D = ItemPickupScene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	pickup.setup(room_id, item_uid, loot_item_id, loot_count)

	_pay_gold(room_id)

	EventBus.enemy_died.emit(room_id, spawn_uid, global_position)
	queue_free()


func _pay_gold(room_id: StringName) -> void:
	var key := "%s::%s" % [String(room_id), String(spawn_uid)]
	var kill_count := GameState.record_enemy_kill(key)
	var is_dungeon := RoomManager.current_room != null and RoomManager.current_room.is_dungeon_room

	var payout := gold_value
	if kill_count > 1 and not is_dungeon:
		payout = int(round(gold_value * REPEAT_KILL_GOLD_FRACTION))
	GameState.add_gold(payout)
