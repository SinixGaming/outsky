class_name RoomTransitionZone
extends Area2D
## A "door." On player contact, hands off to RoomManager with a target scene
## and spawn id. Using a direct PackedScene export (not a string room_id
## lookup) keeps doors refactor-safe and editor-dependency-tracked.

@export var target_room_scene: PackedScene
@export var target_spawn_id: StringName = &"default"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		RoomManager.change_room(target_room_scene, target_spawn_id)
