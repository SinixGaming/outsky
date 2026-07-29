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
## DEV ONLY — draws a magenta line along the floor collider's top surface,
## the exact height the player's feet should rest at. Switch off for release.
@export var debug_show_ground_line: bool = true

## "dynamic_scroll": open/large rooms — camera drags/dead-zones toward
## screen edge, clamped to camera_bounds. "fixed": small interiors — camera
## pinned to camera_bounds center, doesn't move (edge-of-screen doors still
## work unchanged). "boss_arena": camera pinned to center, zoom auto-fit so
## the whole arena is framed. Read by PlayerCamera.configure() via
## RoomManager.change_room().
@export_enum("fixed", "dynamic_scroll", "boss_arena") var camera_mode: String = "dynamic_scroll"
@export var camera_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(960, 640))

## Per-room-type display aspect ratio for the SubViewport letterbox system
## (see ResolutionManager) — the world view is fit to this ratio within
## the actual window, with black bars filling the rest. render_scale is
## an integer downscale factor on the actual render resolution (1 = full
## detail, 2 = render at half-resolution then upscale) — cheap interiors
## can use a coarser scale for a real render-cost saving, not just a
## visual crop.
@export var target_aspect_ratio: Vector2 = Vector2(16, 9)
@export var render_scale: int = 1

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

## When true, Main.gd's Esc-to-menu handler skips its autosave. Set on
## rooms used for testing content that shouldn't silently persist saves
## (e.g. house_start, while chargen/movement are still being iterated on).
@export var disable_autosave: bool = false


## Wall thickness for the auto-generated left/right/top room boundaries
## (see _apply_boundary_walls_placeholder). Purely a physical blocker, no
## visual — real authored wall geometry supersedes it, same as Floor.
const BOUNDARY_WALL_THICKNESS := 40.0


func _ready() -> void:
	add_to_group("rooms")
	_apply_ground_placeholder()
	_apply_floor_collision_placeholder()
	_apply_debug_ground_line()
	_apply_boundary_walls_placeholder()
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


## DEV ONLY — draws a line along the TOP SURFACE of the floor collider, i.e.
## the exact height the player's feet should rest at. Reads the collider
## rather than re-deriving the position, so it shows the real physics ground
## and will disagree visibly if art and collision ever drift apart (the
## "character floats above the floor" class of bug).
func _apply_debug_ground_line() -> void:
	if not debug_show_ground_line:
		return
	var floor_node := get_node_or_null("Floor")
	if floor_node == null:
		return
	var shape_node := floor_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var rect: RectangleShape2D = shape_node.shape
	var top_y: float = floor_node.global_position.y + shape_node.position.y - rect.size.y / 2.0

	var line := Line2D.new()
	line.name = "DebugGroundLine"
	line.width = 2.0
	line.default_color = Color(1.0, 0.15, 0.6, 0.9)
	line.z_index = 500
	var half_w: float = max(rect.size.x, camera_bounds.size.x) / 2.0
	var cx: float = floor_node.global_position.x
	line.add_point(Vector2(cx - half_w, top_y))
	line.add_point(Vector2(cx + half_w, top_y))
	add_child(line)
	print("[Room] debug ground line at y=", top_y)


## Without this, nothing stops the player walking straight off the left,
## right, or top of the room into empty space and falling forever (the
## reported "fall off the map" / "disappear at the edge" bug). Deliberately
## keyed off camera_bounds rather than the Ground sprite's own size/position
## — camera_bounds is the room's true intended extent everywhere else in
## the system (PlayerCamera limits, ResolutionManager aspect fit), whereas
## Ground may legitimately be smaller than the room (e.g. a terrain strip
## at the bottom with open sky above it for a background layer to show
## through) and would give the wrong wall height if used here instead. The
## bottom is intentionally left open — Floor already seals it, and one-way
## platforms need the space above it, not below. Authored geometry (a
## "Bounds" node of any kind) supersedes this — it only fires when that
## slot is empty.
func _apply_boundary_walls_placeholder() -> void:
	if get_node_or_null("Ground") == null:
		return
	if get_node_or_null("Bounds") != null:
		return

	var bounds := Node2D.new()
	bounds.name = "Bounds"
	add_child(bounds)

	var left: float = camera_bounds.position.x
	var right: float = camera_bounds.position.x + camera_bounds.size.x
	var top: float = camera_bounds.position.y
	var bottom: float = camera_bounds.position.y + camera_bounds.size.y
	var mid_x: float = (left + right) / 2.0
	var mid_y: float = (top + bottom) / 2.0
	var full_h: float = bottom - top
	var full_w: float = right - left
	var t := BOUNDARY_WALL_THICKNESS

	_add_boundary_wall(bounds, Vector2(left - t / 2.0, mid_y), Vector2(t, full_h + t * 2.0))
	_add_boundary_wall(bounds, Vector2(right + t / 2.0, mid_y), Vector2(t, full_h + t * 2.0))
	_add_boundary_wall(bounds, Vector2(mid_x, top - t / 2.0), Vector2(full_w + t * 2.0, t))


func _add_boundary_wall(parent: Node2D, world_position: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	parent.add_child(wall)
	wall.global_position = world_position


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
