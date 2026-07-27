extends Node
## The in-memory "current save." Single source of truth that SaveManager
## serializes and RoomManager reads to know where to place the player.

const PlayerSaveDataScript = preload("res://scripts/save/PlayerSaveData.gd")

## Small, deliberately minute per-point conversions for the 5 allocatable
## creation stats (user's own example numbers for damage; flat bonuses for
## stamina/speed kept well under their bases). Health growth is intentionally
## NOT converted here — it's stored in creation_growth only, as an input to
## a future leveling curve, so a fresh character starts at base HP.
const PHYSICAL_DAMAGE_PER_POINT := 0.3
const MAGIC_DAMAGE_PER_POINT := 0.2
const STAMINA_PER_POINT := 1
const SPEED_PER_POINT := 2

var data: PlayerSaveData = PlayerSaveDataScript.new()


## growth_points: Dictionary with up to 5 total points across
## PlayerSaveData.GROWTH_KEYS ("health", "physical_damage", "magic_damage",
## "stamina", "speed"). Validation of the 5-point budget is the UI's job
## (CharacterCreation.gd); this just applies whatever it's given.
func new_game(character_name: String, growth_points: Dictionary, starting_room_id: StringName, starting_spawn_id: StringName = &"default") -> void:
	data = PlayerSaveDataScript.new()
	data.character_name = character_name

	for key in data.creation_growth.keys():
		if growth_points.has(key):
			data.creation_growth[key] = int(growth_points[key])

	data.stats.physical_damage += data.creation_growth["physical_damage"] * PHYSICAL_DAMAGE_PER_POINT
	data.stats.magic_damage += data.creation_growth["magic_damage"] * MAGIC_DAMAGE_PER_POINT
	data.stats.stamina += data.creation_growth["stamina"] * STAMINA_PER_POINT
	data.stats.speed += data.creation_growth["speed"] * SPEED_PER_POINT
	# data.creation_growth["health"] is deliberately not applied to stats.health here.

	data.current_room_id = starting_room_id
	data.current_spawn_id = starting_spawn_id
	data.last_rest_room_id = starting_room_id
	data.last_rest_spawn_id = starting_spawn_id

	EventBus.player_stats_changed.emit()


func set_current_room(room_id: StringName, spawn_id: StringName) -> void:
	data.current_room_id = room_id
	data.current_spawn_id = spawn_id


func set_rest_point(room_id: StringName, spawn_id: StringName) -> void:
	data.last_rest_room_id = room_id
	data.last_rest_spawn_id = spawn_id


func add_item(item_id: StringName, count: int = 1) -> void:
	for entry in data.inventory:
		if entry.get("item_id") == item_id:
			entry["count"] += count
			return
	data.inventory.append({"item_id": item_id, "count": count})


func mark_boss_defeated(boss_id: StringName) -> void:
	if boss_id not in data.defeated_bosses:
		data.defeated_bosses.append(boss_id)


func is_boss_defeated(boss_id: StringName) -> bool:
	return boss_id in data.defeated_bosses


## --- Currency ---

func add_gold(amount: int) -> void:
	data.gold = max(0, data.gold + amount)
	EventBus.gold_changed.emit(data.gold, data.ether)


func add_ether(amount: int) -> void:
	data.ether = max(0, data.ether + amount)
	EventBus.gold_changed.emit(data.gold, data.ether)


## --- Permanent flags (chests, waypoints) ---

func mark_chest_opened(chest_uid: String) -> void:
	if chest_uid not in data.opened_chests:
		data.opened_chests.append(chest_uid)


func is_chest_opened(chest_uid: String) -> bool:
	return chest_uid in data.opened_chests


func record_waypoint_discovered(waypoint_id: String) -> void:
	if waypoint_id not in data.discovered_waypoints:
		data.discovered_waypoints.append(waypoint_id)


func is_waypoint_discovered(waypoint_id: String) -> bool:
	return waypoint_id in data.discovered_waypoints


## --- Permanent enemy kill tracking (distinct from WorldMemory's
## session-scoped respawn tracking) — used to discount repeat-kill gold. ---

## Returns the kill count AFTER recording this kill (1 == first-ever kill).
func record_enemy_kill(enemy_key: String) -> int:
	var count: int = int(data.killed_enemies.get(enemy_key, 0)) + 1
	data.killed_enemies[enemy_key] = count
	return count


func get_enemy_kill_count(enemy_key: String) -> int:
	return int(data.killed_enemies.get(enemy_key, 0))


## --- Death / respawn ---
## Triggered by Main.gd on the player's Health.died signal. Handles every
## data/room-transition consequence of dying; Main.gd separately reacts to
## EventBus.player_respawned to reset the live Player node's resource pools,
## since GameState doesn't hold a scene-tree reference to the player.

func handle_player_death() -> void:
	EventBus.player_died.emit()

	data.gold = 0
	EventBus.gold_changed.emit(data.gold, data.ether)

	_drop_quest_temporary_items()

	# "The rooms you were just in respawn their enemies" — current room and
	# the one before it, per RoomManager.previous_room_id. Resource nodes
	# are untouched: WorldMemory.force_clear_room only ever erases
	# dead_enemies, never harvested_nodes or drops.
	WorldMemory.force_clear_room(RoomManager.current_room_id)
	if RoomManager.previous_room_id != &"":
		WorldMemory.force_clear_room(RoomManager.previous_room_id)

	var rest_room := data.last_rest_room_id
	var rest_spawn := data.last_rest_spawn_id
	await RoomManager.change_room_by_id(rest_room, rest_spawn)

	EventBus.player_respawned.emit(rest_room, rest_spawn)


func _drop_quest_temporary_items() -> void:
	var kept: Array = []
	for entry in data.inventory:
		if not ItemDatabase.is_quest_temporary(entry.get("item_id")):
			kept.append(entry)
	data.inventory = kept
