class_name Room
extends Node2D
## Base script used directly by every room scene's root node. Handles the
## one piece of generic logic every room needs — replaying persisted item
## drops from WorldMemory — so individual rooms never need bespoke code
## for memory to work.

@export var room_id: StringName = &""

const ItemPickupScene := preload("res://scenes/entities/ItemPickup.tscn")
const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

## Phase 1 backdrop: if a direct child Sprite2D named "Ground" has no
## texture assigned, fill it with a flat placeholder so rooms are visible
## before real tileset art exists. Swapping in a real texture later (or a
## TileMap instead) needs no script changes — this only ever fires when
## the slot is still empty.
@export var ground_color: Color = Color(0.15, 0.33, 0.18)
@export var ground_size: Vector2i = Vector2i(960, 640)

## Height of the standable terrain strip generated at the BOTTOM of the
## Ground sprite's bounds (see _apply_floor_collision_placeholder) — not
## the full ground_size.y. The rest of the Ground rect is open-air
## backdrop the player falls/jumps through, same as any side-view room.
@export var floor_thickness: float = 96.0

## "dynamic_scroll": open/large rooms — camera drags/dead-zones toward
## screen edge, clamped to camera_bounds. "fixed": small interiors — camera
## pinned to camera_bounds center, doesn't move (edge-of-screen doors still
## work unchanged). "boss_arena": camera pinned to center, zoom auto-fit so
## the whole arena is framed. Read by PlayerCamera.configure() via
## RoomManager.change_room().
@export_enum("fixed", "dynamic_scroll", "boss_arena") var camera_mode: String = "dynamic_scroll"
@export var camera_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(960, 640))

## Per-room-type render resolution for the SubViewport letterbox system
## (see ResolutionManager). Large/open rooms use a bigger target than
## cheap interiors, which is both the requested visual effect and a real
## render-cost saving.
@export var target_resolution: Vector2i = Vector2i(1920, 1080)

## Which region this room belongs to (e.g. "inithia") — content-authoring
## metadata, not yet consumed by any system.
@export var region_id: StringName = &""

## Can the (future) quick-travel spell be cast FROM this room? False on
## caves/enchanted/one-way rooms per the design.
@export var quick_travel_origin_allowed: bool = true

## Can this room be registered as a sign/spell travel DESTINATION? Explicit
## per-room flag rather than an auto-detected "is this a town" heuristic,
## since some non-town rooms (select dungeons) qualify too.
@export var quick_travel_destination: bool = false

## Enemies here always pay full gold on repeat kills — the explicit
## dungeon exception to the permanent kill-count gold discount.
@export var is_dungeon_room: bool = false


func _ready() -> void:
	add_to_group("rooms")
	_apply_ground_placeholder()
	_apply_floor_collision_placeholder()
	_replay_drops()


func _apply_ground_placeholder() -> void:
	var ground := get_node_or_null("Ground")
	if ground is Sprite2D and ground.texture == null:
		ground.texture = PlaceholderTextureScript.make(ground_size, ground_color)


## Side-view movement needs real floor collision to exist. If the room
## doesn't author its own "Floor" body (real platform/slope geometry),
## generate a StaticBody2D covering only the bottom floor_thickness strip
## of the Ground sprite's bounds — a standable terrain surface, NOT the
## whole backdrop rect (a full-rect collider would embed anything placed
## mid-room, like a spawn point, inside solid ground instead of on top of
## it). Authored geometry silently supersedes this — it only fires when
## the "Floor" slot is empty.
func _apply_floor_collision_placeholder() -> void:
	var ground := get_node_or_null("Ground")
	if ground == null or not (ground is Sprite2D):
		return
	if get_node_or_null("Floor") != null:
		return

	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ground_size.x, floor_thickness)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	add_child(floor_body)

	var ground_bottom: float = ground.global_position.y + ground_size.y / 2.0
	floor_body.global_position = Vector2(ground.global_position.x, ground_bottom - floor_thickness / 2.0)


func _replay_drops() -> void:
	for drop in WorldMemory.get_active_drops(room_id):
		var pickup: Node2D = ItemPickupScene.instantiate()
		add_child(pickup)
		pickup.global_position = drop["position"]
		pickup.setup(room_id, drop["item_uid"], drop["item_id"], drop["count"])


func get_spawn_point(spawn_id: StringName) -> Node2D:
	return _find_spawn_recursive(self, spawn_id)


func _find_spawn_recursive(node: Node, spawn_id: StringName) -> Node2D:
	for child in node.get_children():
		if child is SpawnPoint and child.spawn_id == spawn_id:
			return child
		var found := _find_spawn_recursive(child, spawn_id)
		if found:
			return found
	return null
