class_name RoomTransitionZone
extends Area2D
## A "door." On player contact, hands off to RoomManager with a target
## room_id + spawn id. Uses RoomManager.ROOM_REGISTRY (id -> path) rather
## than holding a direct PackedScene reference to the target room — two
## rooms that door into each other holding direct scene resource
## references to one another is a circular ext_resource dependency, which
## Godot's loader does not handle reliably (confirmed: it fails with
## "referenced non-existent resource" on reload). An id is just a string,
## so no such cycle exists.

@export var target_room_id: StringName
@export var target_spawn_id: StringName = &"default"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		RoomManager.change_room_by_id(target_room_id, target_spawn_id)
