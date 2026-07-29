extends Node
## Owns the currently-loaded room and the fade/load/unload transition
## sequence. Only one room is ever loaded at a time.

## Known room_id -> scene path. The one place a room needs to be reachable
## by id alone rather than by a door's direct PackedScene reference — used
## when restoring current_room_id from a save file.
const ROOM_REGISTRY := {
	"outsky_hill_01": "res://scenes/rooms/outsky/room_hill_01.tscn",
	"outsky_hill_02": "res://scenes/rooms/outsky/room_hill_02.tscn",
	"outsky_house_start": "res://scenes/rooms/outsky/house_start.tscn",
	"outsky_combat_test": "res://scenes/rooms/outsky/combat_test_arena.tscn",
}

var current_room: Room = null
var current_room_id: StringName = &""
## Set right before current_room_id is overwritten below. Lets the death
## flow (Stage 6) force-respawn enemies in "the room(s) the player was
## just in" without needing a full room-history stack.
var previous_room_id: StringName = &""

var _room_container: Node = null
var _player: Player = null
var _fade_overlay: FadeOverlay = null


func register(room_container: Node, player: Player, fade_overlay: FadeOverlay) -> void:
	_room_container = room_container
	_player = player
	_fade_overlay = fade_overlay


func change_room_by_id(room_id: StringName, spawn_id: StringName = &"default") -> void:
	var path: String = ROOM_REGISTRY.get(String(room_id), "")
	if path.is_empty():
		push_error("RoomManager: unknown room_id '%s'" % room_id)
		return
	await change_room(load(path), spawn_id)


func change_room(scene: PackedScene, spawn_id: StringName = &"default") -> void:
	if scene == null:
		push_error("RoomManager.change_room called with a null scene")
		return

	if _fade_overlay:
		await _fade_overlay.fade_out()

	if current_room:
		current_room.queue_free()
		current_room = null
		await get_tree().process_frame

	# current_room_id must be correct BEFORE add_child() — that call
	# synchronously runs the whole new room's _ready() chain, including
	# every Enemy's WorldMemory.is_dead() self-check. Setting it after (as
	# this used to) meant those checks ran against the PREVIOUS room's id,
	# and on the very first-ever room load — before current_room_id had
	# ever been set — against an empty StringName, which crashes on a
	# Godot 4.3 dictionary-assignment quirk with empty StringName keys.
	var new_room: Room = scene.instantiate()
	previous_room_id = current_room_id
	current_room_id = new_room.room_id
	GameState.set_current_room(current_room_id, spawn_id)

	_room_container.add_child(new_room)
	current_room = new_room

	if _player:
		var spawn_point := new_room.get_spawn_point(spawn_id)
		if spawn_point:
			_player.global_position = spawn_point.global_position
		else:
			push_warning("RoomManager: spawn_id '%s' not found in room '%s'" % [spawn_id, current_room_id])

	# Resolution before camera: boss_arena's auto-fit zoom reads the
	# viewport's current size, so the room's display aspect must already
	# be applied by the time the camera configures itself.
	ResolutionManager.set_room_display(new_room.target_aspect_ratio, new_room.render_scale)
	if _player and _player.camera:
		_player.camera.configure(new_room.camera_mode, new_room.camera_bounds, new_room.render_scale)

	if _fade_overlay:
		await _fade_overlay.fade_in()

	EventBus.room_changed.emit(current_room_id)
