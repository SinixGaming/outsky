extends Node
## Per-room transient event log (dead enemies, dropped items) with real
## wall-clock TTLs. Session-only by design — never written to the save file
## (see Phase 1 plan). Uses Time.get_unix_time_from_system() rather than
## engine ticks so expiry is correct even after the game sits idle or the
## room simply hasn't been visited in a while.

const WorldMemoryConfigScript = preload("res://scripts/core/WorldMemoryConfig.gd")

## Dictionary[room_id: StringName] -> {
##   "dead_enemies": Dictionary[spawn_uid: StringName] -> death_unix_timestamp: float,
##   "drops": Dictionary[item_uid: StringName] -> {item_id, count, position, drop_unix_timestamp},
##   "harvested_nodes": Dictionary[node_uid: StringName] -> harvest_unix_timestamp: float
## }
## harvested_nodes is deliberately its own dict, never touched by
## force_clear_room() — this is what makes resource nodes structurally
## immune to the player-death respawn-forcing flow.
var _rooms: Dictionary = {}

var config: WorldMemoryConfig = WorldMemoryConfigScript.new()

var _sweep_timer: Timer


func _ready() -> void:
	var loaded_config: Resource = load("res://data/config/world_memory_config.tres")
	if loaded_config is WorldMemoryConfig:
		config = loaded_config

	_sweep_timer = Timer.new()
	_sweep_timer.wait_time = config.prune_sweep_interval_seconds
	_sweep_timer.autostart = true
	_sweep_timer.timeout.connect(_on_sweep_timeout)
	add_child(_sweep_timer)


func _get_room(room_id: StringName) -> Dictionary:
	if not _rooms.has(room_id):
		_rooms[room_id] = {"dead_enemies": {}, "drops": {}, "harvested_nodes": {}}
	return _rooms[room_id]


func _now() -> float:
	return Time.get_unix_time_from_system()


## --- Enemies ---

func record_death(room_id: StringName, spawn_uid: StringName) -> void:
	_get_room(room_id)["dead_enemies"][spawn_uid] = _now()


func is_dead(room_id: StringName, spawn_uid: StringName) -> bool:
	_prune_room(room_id)
	var room := _get_room(room_id)
	return room["dead_enemies"].has(spawn_uid)


## --- Item drops ---

func record_drop(room_id: StringName, item_uid: StringName, item_id: StringName, count: int, drop_position: Vector2) -> void:
	_get_room(room_id)["drops"][item_uid] = {
		"item_id": item_id,
		"count": count,
		"position": drop_position,
		"drop_unix_timestamp": _now(),
	}


func remove_drop(room_id: StringName, item_uid: StringName) -> void:
	var room := _get_room(room_id)
	room["drops"].erase(item_uid)


func get_active_drops(room_id: StringName) -> Array:
	_prune_room(room_id)
	var room := _get_room(room_id)
	var result: Array = []
	for item_uid in room["drops"].keys():
		var entry: Dictionary = room["drops"][item_uid]
		result.append({
			"item_uid": item_uid,
			"item_id": entry["item_id"],
			"count": entry["count"],
			"position": entry["position"],
		})
	return result


## --- Resource / harvest nodes ---
## Own independent timer, deliberately untouched by force_clear_room() —
## farmable nodes must not be resettable by dying on purpose.

func record_harvest(room_id: StringName, node_uid: StringName) -> void:
	_get_room(room_id)["harvested_nodes"][node_uid] = _now()


func is_harvested(room_id: StringName, node_uid: StringName) -> bool:
	_prune_room(room_id)
	return _get_room(room_id)["harvested_nodes"].has(node_uid)


## --- Death-triggered forced respawn ---

## Unconditionally clears dead_enemies for one room, regardless of their
## TTL — called only by the player-death flow ("rooms you were just in
## respawn their enemies"). Deliberately does NOT touch harvested_nodes or
## drops; those have their own independent lifetimes.
func force_clear_room(room_id: StringName) -> void:
	if not _rooms.has(room_id):
		return
	_rooms[room_id]["dead_enemies"].clear()


## --- Pruning ---

func _prune_room(room_id: StringName) -> void:
	if not _rooms.has(room_id):
		return
	var room: Dictionary = _rooms[room_id]
	var now := _now()

	var expired_enemies: Array = []
	for spawn_uid in room["dead_enemies"].keys():
		var death_time: float = room["dead_enemies"][spawn_uid]
		if now - death_time >= config.enemy_respawn_seconds:
			expired_enemies.append(spawn_uid)
	for spawn_uid in expired_enemies:
		room["dead_enemies"].erase(spawn_uid)

	var expired_drops: Array = []
	for item_uid in room["drops"].keys():
		var drop_time: float = room["drops"][item_uid]["drop_unix_timestamp"]
		if now - drop_time >= config.item_expiry_seconds:
			expired_drops.append(item_uid)
	for item_uid in expired_drops:
		room["drops"].erase(item_uid)

	var expired_harvests: Array = []
	for node_uid in room["harvested_nodes"].keys():
		var harvest_time: float = room["harvested_nodes"][node_uid]
		if now - harvest_time >= config.resource_respawn_seconds:
			expired_harvests.append(node_uid)
	for node_uid in expired_harvests:
		room["harvested_nodes"].erase(node_uid)


func _on_sweep_timeout() -> void:
	# Data-only sweep: prunes every known room's records but never mutates a
	# currently-loaded room's live nodes. Respawn/despawn is only realized
	# the next time that room scene is (re)instantiated — avoids an enemy
	# popping into existence while the player is standing there.
	for room_id in _rooms.keys():
		_prune_room(room_id)
